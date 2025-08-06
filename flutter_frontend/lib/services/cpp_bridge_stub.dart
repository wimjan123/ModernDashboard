// Stub implementation for platforms without FFI or web support
abstract class CppBridgeInterface {
  String getNewsData();
  String getWeatherData();
  String getTodoData();
  String getMailData();
  bool startStream(String streamUrl);
  bool initializeEngine();
  bool shutdownEngine();
}

CppBridgeInterface createCppBridge() => _CppBridgeStub();

class _CppBridgeStub implements CppBridgeInterface {
  @override
  String getNewsData() => '[]';

  @override
  String getWeatherData() => '{"location":"Unknown","temperature":0,"conditions":"N/A"}';

  @override
  String getTodoData() => '[]';

  @override
  String getMailData() => '[]';

  @override
  bool startStream(String streamUrl) => false;

  @override
  bool initializeEngine() => true;

  @override
  bool shutdownEngine() => true;
}