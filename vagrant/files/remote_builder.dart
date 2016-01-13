import 'dart:core';
import 'dart:io';
import 'dart:convert';

const String HOST = '10.6.6.6';
const int PORT = 10666;

const String DART = '/usr/bin/dart';
const String DEV_DIR = '/vagrant';
const String RUN_DIR = '/vagrant-run';
const String SYNC_FOLDER = '/vagrant/vagrant/scripts/gcloud/sync_folder.sh';
const String SYNC_PUBSPEC = '/vagrant/vagrant/scripts/gcloud/sync_pubspec.sh';

/**
 * Evaluates the recieved [data], executes the extracted instruction and
 * returns the result. Currently only 'build.dart' is allowed as instruction.
 */
String handleInstruction(String data) {
  var response = '';

  List<String> args = data.split(' ');

  // We only handle build.dart instructions
  if (args.first != 'build.dart') return '0';

  var location = args[1];

  // Only the arguments for `build.dart`
  var buildArgs = args.sublist(2);

  var fromPath = '$DEV_DIR/$location';
  // `test` is a special "project" name, that is used to run tests in the vagrant machine
  var toPath = location != 'test' ? '$RUN_DIR/$location' : '${DEV_DIR}/vagrant/test';

  buildArgs.add('--local');

  print('executing: "dart ${buildArgs.join(' ')}" in directory: "$fromPath"');

  buildArgs.insert(0, 'build.dart');

  var result = Process.runSync(DART, buildArgs,
      workingDirectory: fromPath, environment: readVagrantEnvironment(), includeParentEnvironment: true);

  syncFiles(fromPath, toPath);

  response = result.exitCode.toString() + '\n';
  response += result.stdout + '\n' + result.stderr;
  return response;
}

/// Returns the vagrant environment from /etc/environment as a Map
Map<String, String> readVagrantEnvironment() {
  var environmentFile = new File('/etc/environment');
  return environmentStringToMap(environmentFile.readAsStringSync());
}

Map<String, String> environmentStringToMap(String environment) {
  var vagrantEnvironment = {};
  for (String line in environment.split('\n')) {
    if (line.contains('=')) {
      var keyValue = line.split('=');
      vagrantEnvironment[keyValue.first] = keyValue.last;
    }
  }
  // removing the PATH since it should be in the parent environment
  vagrantEnvironment.remove('PATH');
  return vagrantEnvironment;
}

/**
 * Syncs changed files from [fromPath] to [toPath]. Deletes files not present in [fromPath].
 * If [toPath] doesn't exist creates it. If a file on [fromPath] called '.rsyncignore' is present
 * patterns in this file are used to ignore files to copy or delete.
 */
void syncFiles(fromPath, toPath) {
  print('copying files from "$fromPath" to "$toPath"');

  /// Using synced process to copy stuff for now so we can notice if
  /// copying duration becomes a problem at some point.
  var args = [fromPath, toPath];
  var result = Process.runSync(SYNC_FOLDER, args);

  print(result.stdout);
  print(result.stderr);

  /// Sync pubspec.yaml extra so we can have it in the ignore file
  /// for rsync. This avoids having it synced over every time because it
  /// is being modified in the sync.
  args = [fromPath + '/pubspec.yaml', toPath];
  result = Process.runSync(SYNC_PUBSPEC, args);

  print(result.stdout);
  print(result.stderr);
}

/**
 * Starts the build-Server which listens for instructions and responds with
 * the result of running the received instruction.
 */
void startServer() {
  var result;

  ServerSocket.bind(HOST, PORT).then((ServerSocket serverSocket) {
    print('listening for connections now');
    serverSocket.listen((socket) {
      socket.transform(UTF8.decoder).listen((String data) {
        result = handleInstruction(data);
        socket.write(result);
        socket.destroy();
      });
    });
  });
}

void main() {
  startServer();
}
