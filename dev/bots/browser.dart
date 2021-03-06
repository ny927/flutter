// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' as io;

import 'package:meta/meta.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';

import 'package:flutter_devicelab/framework/browser.dart';

/// Runs Chrome, opens the given `appUrl`, and returns the result reported by the
/// app.
///
/// The app is served from the `appDirectory`. Typically, the app is built
/// using `flutter build web` and served from `build/web`.
///
/// The launched app is expected to report the result by sending an HTTP POST
/// request to "/test-result" containing result data as plain text body of the
/// request. This function has no opinion about what that string contains.
Future<String> evalTestAppInChrome({
  @required String appUrl,
  @required String appDirectory,
  int serverPort = 8080,
  int browserDebugPort = 8081,
}) async {
  io.HttpServer server;
  Chrome chrome;
  try {
    final Completer<String> resultCompleter = Completer<String>();
    server = await io.HttpServer.bind('localhost', serverPort);
    final Cascade cascade = Cascade()
      .add((Request request) async {
        if (request.requestedUri.path.endsWith('/test-result')) {
          resultCompleter.complete(await request.readAsString());
          return Response.ok('Test results received');
        }
        return Response.notFound('');
      })
      .add(createStaticHandler(appDirectory));
    shelf_io.serveRequests(server, cascade.handler);
    final io.Directory userDataDirectory = io.Directory.systemTemp.createTempSync('chrome_user_data_');
    chrome = await Chrome.launch(ChromeOptions(
      headless: true,
      debugPort: browserDebugPort,
      url: appUrl,
      userDataDirectory: userDataDirectory.path,
      windowHeight: 500,
      windowWidth: 500,
    ), onError: resultCompleter.completeError);
    return await resultCompleter.future;
  } finally {
    chrome?.stop();
    await server?.close();
  }
}
