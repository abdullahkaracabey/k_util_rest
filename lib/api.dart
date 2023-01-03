import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:k_util/k_util.dart';

mixin Api {
  bool hasConnection = true;
  String get baseUrl;

  BaseAuthManager get authManager;

  VoidCallback? unAuthorizedCallback;

  Future<Map<String, dynamic>> postRequest(String url, dynamic body) async {
    try {
      var currentUrl = "";

      if (url.startsWith("http") || url.startsWith("www")) {
        currentUrl = url;
      } else {
        currentUrl = '$baseUrl/$url';
      }

      var dio = _getDio();

      dio.options.headers[HttpHeaders.contentTypeHeader] =
          "application/x-www-form-urlencoded";

      var response = await dio.post(currentUrl, data: body);

      return _handledResponse(response);
    } catch (e) {
      if (e is DioError) {
        _handledResponse(e.response!);
      } else if (e is AppException) {
        rethrow;
      }

      throw AppException.kUnknownError;
    }
  }

  // Future<Map<String, dynamic>> multipartRequest(String url, File file) async {
  //   try {
  //     var request =
  //         await http.MultipartRequest("POST", Uri.parse("$_baseUrl/$url"));

  //     request.files.add(http.MultipartFile(
  //         "picture", file.readAsBytes().asStream(), file.lengthSync()));

  //     var response = await request.send();

  //     return Map<String, dynamic>();
  //     // return _handledResponse(response);
  //   } catch (e) {
  //     throw AppException(message: e.toString());
  //   }
  // }

  Future<Map<String, dynamic>?> formDataRequest(String url, File file) async {
    try {
      String fileName = file.path.split('/').last;

      var splittedFileName = fileName.split(".");
      var extension = splittedFileName.length > 0 ? splittedFileName.last : "";

      FormData data = FormData.fromMap({
        "image": await MultipartFile.fromFile(file.path,
            filename: "${Uuid().v4()}.$extension",
            contentType: MediaType("image", "png")),
      });
      debugPrint("form data: $data");
      Dio dio = _getDio();

      dio.options.connectTimeout = 5000;
      dio.options.receiveTimeout = 10000;
      dio.options.sendTimeout = 10000;

      var currentUrl = "";

      if (url.startsWith("http") || url.startsWith("www")) {
        currentUrl = url;
      } else {
        currentUrl = '$baseUrl/$url';
      }

      var response = await dio.post(currentUrl, data: data);

      return _handledResponse(response);
    } catch (e) {
      if (e is DioError && e.response != null) {
        _handledResponse(e.response!);
      } else {
        throw AppException(message: e.toString());
      }
    }
  }

  Future<dynamic> getRequest(String url,
      {Map<String, dynamic>? headers}) async {
    try {
      var currentUrl = "";

      if (url.startsWith("http") || url.startsWith("www")) {
        currentUrl = url;
      } else {
        currentUrl = '$baseUrl/$url';
      }

      var dio = _getDio();

      if (headers != null) {
        dio.options.headers = headers;
      }

      var response = await dio.get(currentUrl);

      return _handledResponse(response);
    } catch (e) {
      if (e is DioError) {
        if (e.response != null) {
          _handledResponse(e.response!);
          return;
        }
      }
      throw AppException(message: e.toString());
    }
  }

  dynamic _handledResponse(Response response) {
    if (response.statusCode! / 100 == 2) {
      return response.data;
    } else if (response.statusCode == 401) {
      if (unAuthorizedCallback != null) {
        unAuthorizedCallback!();
      } else {
        if (response.data["message"] != null) {
          throw AppException(
              code: response.statusCode, message: response.data["message"]);
        }
        throw AppException.kUnAuthorized;
      }
    } else if (response.statusCode == 500) {
      throw AppException.kUnknownError;
    } else if (response.statusCode != null &&
        response.data["message"] != null) {
      var code = response.statusCode;
      var message = response.data["message"];
      throw AppException(code: code, message: message);
    }

    throw AppException.kUnknownError;
  }

  download({required String url, required String savePath}) async {
    await _getDio().download(url, savePath);
  }

  Dio _getDio() {
    var dio = Dio();
    // dio.options.connectTimeout = 5000;
    // dio.options.receiveTimeout = 10000;
    // dio.options.sendTimeout = 10000;
    var token = authManager.authToken;
    if (token != null) {
      dio.options.headers[HttpHeaders.authorizationHeader] = "Bearer $token";

      debugPrint("Token: $token");
    } else {
      debugPrint("Token not exist");
    }

    return dio;
  }
}
