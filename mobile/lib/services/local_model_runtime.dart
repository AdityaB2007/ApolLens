// Gavin - A cancellable offline runtime shared by native and downloaded models.
abstract interface class LocalModelRuntime {
  Future<void> initialize();
  Future<void> install(void Function(int progress) onProgress);
  Future<bool> loadActiveModel();
  Future<String> generate(String systemInstruction, String prompt);
  Future<void> cancelGeneration();
  Future<void> dispose();
}
