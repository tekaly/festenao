// ignore_for_file: implementation_imports

import 'package:festenao_common/data/festenao_data.dart';

//@deprecated
var testProjectId = demoFbProjectId;
var demoFbProjectId = 'festenao-free-dev';
const demoSourceId = 'BLXblf7NNlE0e0RgcrpH';
//@deprecated
const testAppId = demoSourceId;
var testRootPath = 'test/$demoSourceId';

const devRootPath = 'app/$demoSourceId';
var demoAppRootPath = devRootPath;
const demoAppPackageName = 'com_festenao_demo';

var demoDataGlobalsOptions = FestenaoDataGlobalsOptions(
    fbProjectId: demoFbProjectId, sourceId: demoSourceId);
