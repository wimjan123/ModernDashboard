import '../services/mock_data_service.dart';

class FfiBridge {
  static bool get isSupported => false;

  static bool initializeEngine() {
    MockDataService().initialize();
    return true; // show "Dashboard Online"
  }

  static bool shutdownEngine() => true;

  // Delegate to shared mock service
  static String getNewsData() => MockDataService().getNewsData();
  static String getWeatherData() => MockDataService().getWeatherData();
  static String getTodoData() => MockDataService().getTodoData();
  static String getMailData() => MockDataService().getMailData();

  // Static methods with trivial behavior / delegation
  static bool updateWidgetConfig(String widgetId, String configJson) => true;
  static bool addNewsFeed(String url) => true;
  static bool removeNewsFeed(String url) => true;
  static bool startStream(String url) => true;
  static bool stopStream(String streamId) => true;
  static String getStreamData(String streamId) =>
      MockDataService().getStreamData();
  static bool updateWeatherLocation(String location) => true;

  static bool addTodoItem(String jsonData) =>
      MockDataService().addTodoItem(jsonData);
  static bool updateTodoItem(String jsonData) =>
      MockDataService().updateTodoItem(jsonData);
  static bool deleteTodoItem(String itemId) =>
      MockDataService().deleteTodoItem(itemId);

  static bool configureMailAccount(String jsonConfig) => true;
}
