import org.awaitility.Awaitility;

public class Main {
  public static void main(String[] args) {
    Awaitility.await().until(() -> true);
  }
}
