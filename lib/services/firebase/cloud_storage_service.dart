import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:wvems_protocols/_internal/utils/utils.dart';
import 'package:wvems_protocols/models/models.dart';
import 'package:wvems_protocols/services/services.dart';

/// Firebase downloads default to 10mb.
/// If we ever need to call ref.getData(), we will set the max
/// filesize to be the known PDF filesize + 2 mb as buffer
/// this constant would be used for the 2mb buffer
///
/// const int _kTwoMbExtra = 2097152;

// Use the Firebase controller to access methods within this service.
class CloudStorageService {
  FirebaseStorage storage = FirebaseStorage.instance;

  Future<PdfTableOfContentsState> fetchTocJsonFromReference(
      Reference reference) async {
    late final PdfTableOfContentsState tocJsonState;

    // final download = await reference.getData();

    final downloadUrl = await reference.getDownloadURL();
    final response = await http.get(Uri.parse(downloadUrl));

    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      tocJsonState =
          await BundleValidationUtil().loadTocJsonFromJsonString(response.body);
      // return _bundleValidationUtil.fromJson(jsonDecode(response.body));
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load JSON from Firebase');
      // tocJsonState = PdfTableOfContentsState.error(error, stackTrace);
    }
    return tocJsonState;
  }

  Future<int?> fetchFileSizeFromReference(Reference reference) async {
    final FullMetadata fullMetadata = await reference.getMetadata();
    return fullMetadata.size;
  }

  Future<bool> fetchBundleFromCloud(
      ProtocolBundleAsFirebaseRefs bundle, VoidCallback onComplete) async {
    final DocumentsService _documentsService = DocumentsService();

    late final bool status;

    try {
      final Directory localDir = await _documentsService.getAppDirectory();

      await _saveRefToLocalDirectory(bundle.jsonRef, localDir);
      await _saveRefToLocalDirectory(bundle.tocJsonRef, localDir);
      await _saveRefToLocalDirectory(bundle.pdfRef, localDir)
          .whenComplete(onComplete);
      print('bundle saved from cloud for ${bundle.bundleId}');
      status = true;
    } catch (error) {
      print('error downloading bundle from cloud: $error');
      status = false;
    }

    return status;
  }

  Future<bool> _saveRefToLocalDirectory(
      Reference reference, Directory localDir) async {
    late final DownloadTask downloadTask;
    late final File file;
    late final bool response;
    try {
      final String fullPath = '${localDir.path}/${reference.fullPath}';

      if (File(fullPath).existsSync()) {
        file = File(fullPath);
      } else {
        file = await File(fullPath).create(recursive: true);
      }

      downloadTask = reference.writeToFile(file);
      await downloadTask.whenComplete(() => response = true);
      while (!response) {}
      return response;
    } catch (error) {
      print('error creating new file or writing to existing file: $error');
      return false;
    }
  }

  /// List all subdirectories within the main folder
  /// This does not check for subdirectories within a subdirectory (recursive)
  Future<List<Reference>> subDirectoriesList() async {
    late final List<Reference> subDirectoriesRef;

    try {
      final ListResult firebaseRefList = await storage.ref().listAll();
      subDirectoriesRef = firebaseRefList.prefixes;
    } catch (error) {
      print('error parsing Firebase storage subdirectories: $error');
      subDirectoriesRef = [];
    }

    return subDirectoriesRef;
  }

  /// List all files within a single folder
  Future<List<Reference>> filesList(Reference reference) async {
    final filesList = <Reference>[];
    try {
      final allFiles = await reference.listAll();
      allFiles.items.forEach((e) => filesList.add(e));
    } catch (error) {
      print('error parsing Firebase storage files: $error');
    }
    return filesList;
  }

  Future<void> listExample() async {
    // List of items in the storage reference

    final ListResult allFolders = await storage.ref().listAll();

    // PDF Files in Firebase Storage
    final ListResult result = await storage.ref().child('pdf').listAll();

    // JSON Files in Firebase Storage
    final ListResult jsonResult = await storage.ref().child('json').listAll();

    //Simple Print Statement - Zaps
    print('Ready to list examples!');

    // Get the app directory
    final directory = await getApplicationDocumentsDirectory();

    // Get list of items in app directory
    final List contents =
        directory.listSync(recursive: true, followLinks: true);

    // Get pdf filenames
    result.items.forEach((Reference ref) {
      // List Files in Firebase Storage - pdf directory
      String tmpFileName = ref.fullPath;
      print(tmpFileName + ' is available in Firebase Storage');

      // Get filename and alter to match the Application Doc directory
      const start = 'pdf/';
      tmpFileName = tmpFileName.substring(start.length);
      tmpFileName = directory.path + '/' + tmpFileName;

      if (contents.contains(tmpFileName)) {
        print(tmpFileName + ' is here!');
      } else {
        print(tmpFileName + ' is not here!');
        print('Downloading');
        final File downloadToFile = File(tmpFileName);
        ref.writeToFile(downloadToFile);
      }
    });

    jsonResult.items.forEach((Reference ref) {
      String tmpJSONFileName = ref.fullPath;
      print(tmpJSONFileName + ' is available in Firebase Storage');

      // Get filename and alter to match the Application Doc directory
      const start = 'json/';
      tmpJSONFileName = tmpJSONFileName.substring(start.length);
      tmpJSONFileName = directory.path + '/' + tmpJSONFileName;
      print(tmpJSONFileName);

      if (contents.contains(tmpJSONFileName)) {
        print(tmpJSONFileName + ' is here!');
      } else {
        print(tmpJSONFileName + ' is not here!');
        print('Downloading');
        final File downloadToFile = File(tmpJSONFileName);
        ref.writeToFile(downloadToFile);
      }
    });

    for (int i = 0; i < contents.length; i++) {
      final item = contents[i];
      print(item);
    }

    result.prefixes.forEach((Reference ref) {
      print('Found directory: $ref');
    });
  }
}
