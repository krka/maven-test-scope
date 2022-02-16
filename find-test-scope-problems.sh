#!/bin/bash

if [ ! which xmlstarlet 2> /dev/null ] ; then
  echo "xmlstarlet is not installed"
  exit 1
fi

function deps {
  local out=$1
  local in=$2
  mvn -B dependency:list -DoutputFile=$out.raw -f $in &> /dev/null
  cat $out.raw | grep "^ "| grep ":compile" | cut -d : -f 1-2 | sort > ${out}
}

function check {
  echo "Running check for $(pwd):"

  if grep -F "<modules>" pom.xml > /dev/null ; then
    for file in $(find . | grep "/pom.xml$") ; do
      local dir=$(dirname $file)
      if [ $dir != "." ] ; then
        pushd $dir &> /dev/null
        check
        popd &> /dev/null
      fi
    done
  else

    set -e
    xmlstarlet ed -P -N ns=http://maven.apache.org/POM/4.0.0 -d 'ns:project/ns:dependencies/ns:dependency[ns:scope="test"]' pom.xml > pom.notest.xml
    deps dependency-list.txt pom.xml
    deps dependency-list.notest.txt pom.notest.xml
    set +e

    diff -u dependency-list.txt dependency-list.notest.txt

    if [ 0 -ne $? ] ; then
      echo "Found some differences! Further investigation is suggested."
    fi
  fi
}

check
