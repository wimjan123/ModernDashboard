// Web stub for FFI Bridge
// This file is used on web platform where FFI is not available

class FfiBridge {
  static bool get isSupported => false;

  static bool initializeEngine() => false;
  static bool shutdownEngine() => false;

  static String getNewsData() => '[]';
  static String getWeatherData() => '{}';
  static String getTodoData() => '[]';
  static String getMailData() => '[]';

  static bool updateWidgetConfig(String widgetId, String configJson) => false;
  static bool addNewsFeed(String url) => false;
  static bool removeNewsFeed(String url) => false;
  static bool startStream(String url) => false;
  static bool stopStream(String streamId) => false;
  static String getStreamData(String streamId) => '{}';
  static bool updateWeatherLocation(String location) => false;
  static bool addTodoItem(String jsonData) => false;
  static bool updateTodoItem(String jsonData) => false;
  static bool deleteTodoItem(String itemId) => false;
  static bool configureMailAccount(String jsonConfig) => false;
}