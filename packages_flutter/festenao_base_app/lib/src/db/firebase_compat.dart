/// To initialize before access
// ignore_for_file: public_member_api_docs

library;

String get appProjectId => appDataContext.projectId;

String get appStorageRootPath => appDataContext.rootPath;

/// We always need storage access (for sync and pictures if any)
class AppDataContext {
  final String projectId;
  final String rootPath;

  AppDataContext({required this.projectId, required this.rootPath});
}

late AppDataContext appDataContext;
