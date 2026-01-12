// ignore_for_file: implementation_imports

import 'package:festenao_common/data/festenao_data.dart';

/// Test project ID.
//@deprecated
var testProjectId = demoFbProjectId;

/// Demo Firebase project ID.
var demoFbProjectId = 'festenao-free-dev';

/// Demo source ID.
const demoSourceId = 'BLXblf7NNlE0e0RgcrpH';

/// Test app ID.
//@deprecated
const testAppId = demoSourceId;

/// Test root path.
var testRootPath = 'test/$demoSourceId';

/// Development root path.
const devRootPath = 'app/$demoSourceId';

/// Demo app root path.
var demoAppRootPath = devRootPath;

/// Demo app package name.
const demoAppPackageName = 'com_festenao_demo';

/// Demo data globals options.
var demoDataGlobalsOptions = FestenaoDataGlobalsOptions(
  fbProjectId: demoFbProjectId,
  sourceId: demoSourceId,
);
