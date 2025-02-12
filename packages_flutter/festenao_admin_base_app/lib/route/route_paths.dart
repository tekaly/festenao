import 'package:tekartik_app_navigator_flutter/content_navigator.dart';

class ProjectsContentPath extends ContentPathBase {
  final _part = ContentPathPart('projects');
  @override
  List<ContentPathField> get fields => [_part];
}

/*
class MarkdownGuideContentPath extends ContentPathBase {
  final _part = ContentPathPart('markdown_guide');
  @override
  List<ContentPathField> get fields => [_part];
}

class SettingsContentPath extends ContentPathBase {
  final _part = ContentPathPart('settings');
  @override
  List<ContentPathField> get fields => [_part];
}

class SettingProjectsContentPath extends ContentPathBase {
  final _part = ContentPathField('setting', 'projects');
  @override
  List<ContentPathField> get fields => [_part];
}

class LocalProjectContentPath extends ContentPathBase {
  final project = ContentPathField('local_project');
  @override
  List<ContentPathField> get fields => [project];
}
*/
class SyncedProjectContentPath extends ContentPathBase {
  final project = ContentPathField('admin_project');
  @override
  List<ContentPathField> get fields => [project];
}

class RootSyncedProjectContentPath extends ContentPathBase {
  final project = ContentPathField('project');
  @override
  List<ContentPathField> get fields => [project];
}

class _SubContentPath extends ContentPathBase {
  late final ContentPathPart _part;
  _SubContentPath(String sub) {
    _part = ContentPathPart(sub);
  }
  @override
  List<ContentPathField> get fields => [_part];
}

class _ProjectSubContentPath extends RootSyncedProjectContentPath {
  late final ContentPathPart _part;
  _ProjectSubContentPath(String sub) {
    _part = ContentPathPart(sub);
  }
  @override
  List<ContentPathField> get fields => [...super.fields, _part];
}

class ProjectMetasContentPath extends _ProjectSubContentPath {
  ProjectMetasContentPath() : super('metas');
}

class ProjectInfosContentPath extends _ProjectSubContentPath {
  ProjectInfosContentPath() : super('infos');
}

class HomeContentPath extends _SubContentPath {
  HomeContentPath() : super('home');
}
/*
class ProjectInviteContentPath extends ContentPathBase {
  final invite = ContentPathField('invite');
  final project = ContentPathField('project');
  @override
  List<ContentPathField> get fields => [invite, project];
}

class LocalProjectNotesContentPath extends LocalProjectContentPath {
  final _part = ContentPathPart('notes');
  @override
  List<ContentPathField> get fields => [project, _part];
}

class SyncedProjectNotesContentPath extends SyncedProjectContentPath {
  final _part = ContentPathPart('notes');
  @override
  List<ContentPathField> get fields => [project, _part];
}

class LocalProjectNoteContentPath extends LocalProjectContentPath {
  final note = ContentPathField('note');
  @override
  List<ContentPathField> get fields => [project, note];
}

class SyncedProjectNoteContentPath extends SyncedProjectContentPath {
  final note = ContentPathField('note');
  @override
  List<ContentPathField> get fields => [project, note];
}
*/
