## Are maven scopes broken?

Are scopes in Maven broken or do the simply not work the way you would expect?
The rules they follow may very well be different from your intuition.

For example, let's look at the test scope.
When developers add a dependency as a test scope in maven like this:


        <dependency>
            <groupId>org.hamcrest</groupId>
            <artifactId>hamcrest</artifactId>
            <version>2.1</version>
            <scope>test</scope>
        </dependency>

the intention may be "I need this dependency for the tests I am writing, but I do no need it for production code".

However, this intention does not match what Maven is actually doing which is more along the lines of:
"The artifact should only exist in the test scope and must definitely not be present in production code (i.e. the compile scope)"

Usually, this distinction is not important, since the dependencies that people tend to pull into tests explicitly
are the ones that are already missing from the compile scope and test artifacts are usually not something that
production code depends on.

That doesn't mean that it never happens though, especially since dependencies can end up being a very large graph,
and people do not usually traverse the full graph to check if any transitive dependencies are conflicting with your tests.

This means that simply by upgrading or adding a dependency to your codebase, you may get runtime crashes simply by
having a new transitive dependency that you have already added to your code in test scope.

## The actual problem

It is my personal opinion that scopes in maven are not very well thought out.
It appears to be modeled as a big set of dependency artifacts per maven module, where each artifact has exactly one scope.

The maven dependency resolution rules also make root level dependency declarations take precedence over transitively
declared dependencies, which means you can accidentally break transitive dependencies by moving their dependencies
from compile to test.

I think a better model would be to have test and compile live in separate worlds. Adding a dependency with test scope would
only update a separate set of artifacts. Thus, the artifacts that are used for testing would be the union of all the
compile scope artifacts as well as also adding the artifacts marked with test scope (and their dependencies).

## Symptoms that can affect you

There are basically three bad things that can happens if you accidentally replace a compile time

1. You get a compilation error since one of your dependencies no longer is used in the production code.
   This is the best case, since it's very easy to detect.
2. You get a crash in runtime, since classes you are depending on transitively longer exist on the classpath.
   This is annoying, but hopefully somewhat quick to identify. This may have bad impact if software has been shipped that
   is hard to update.
3. You get unexpected behavior, if the classes that have disappeared where dynamically loaded and used to automatically enable
   certain behavior. This may go unnoticed for a long time, which is potentially very scary.

## How do we avoid this?

There are certain workarounds we can do to avoid this:

1. Add all test dependencies with scope=compile instead. This makes the production artifact bigger, but that may not be a big problem.
2. Create a maven submodule specifically to host all tests instead of having them in the same module as the production code.
   This means that changes to scopes for the test module will not affect production code.
3. Create some tooling to detect when some artifacts are hidden from production code by the usage of test scope.

## Tooling
I have created a very simple and stupid [bash script](find-test-scope-problems.sh) to try to detect problems like this.

What it does is basically:
1. Compute the list of compile time dependencies using `mvn dependency:list`
2. Create a modified pom file that removes all dependencies that have `<scope>test</test>` and run `mvn dependency:list`
   for that too.
3. Compare the lists to see if any compile time dependencies have disappeared.
   Any difference here could be a potential problem.

This tooling is far from optimal. It would be nice if someone would more brain capacity would create a better tool -
or perhaps even fix maven itself?

## Examples
This repository also contains a minimal maven setup that reproduces the issue. The Main class does not compile,
since there is a test scope set that hides a dependency from production code.
If `<scope>test</test>` is removed, it will start to compile.
