import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:frontend/config/api_config.dart';

class UserService {
  /// Upload profile picture and return the image URL
  static Future<String?> uploadProfilePicture(
    String token,
    dynamic imageFile, // Can be File (mobile) or XFile (web/mobile)
  ) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/profile/picture/upload");

      print("Uploading to: $url");

      // Create multipart request
      var request = http.MultipartRequest('POST', url);
      request.headers.addAll({
        "Authorization": "Bearer $token",
      });

      // Handle both File and XFile
      if (imageFile is XFile) {
        // XFile from image_picker
        final bytes = await imageFile.readAsBytes();
        final fileName =
            imageFile.name.isNotEmpty ? imageFile.name : 'photo.jpg';
        request.files.add(
          http.MultipartFile.fromBytes(
            'image',
            bytes,
            filename: fileName,
          ),
        );
      } else if (imageFile is File) {
        // File from dart:io
        request.files.add(
          await http.MultipartFile.fromPath(
            'image',
            imageFile.path,
          ),
        );
      } else {
        print("Invalid image type: ${imageFile.runtimeType}");
        return null;
      }

      print("Sending upload request...");

      // Send the request
      var response = await request.send();
      var responseBody = await response.stream.bytesToString();

      print("Upload response status: ${response.statusCode}");
      print("Upload response body: $responseBody");

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Parse the response to get the URL
        final jsonResponse = jsonDecode(responseBody);
        
        print("Parsed response: $jsonResponse");
        print("User object: ${jsonResponse['user']}");
        
        // The backend returns the full user object with profile_picture_url
        final uploadedUrl = jsonResponse['user']?['profile_picture_url'] ??
                           jsonResponse['data']?['profile_picture_url'] ?? 
                           jsonResponse['profile_picture_url'] ??
                           jsonResponse['url'];

        print("Extracted URL: $uploadedUrl");

        if (uploadedUrl != null && uploadedUrl.toString().isNotEmpty) {
          print("✅ Image uploaded successfully: $uploadedUrl");
          return uploadedUrl.toString();
        } else {
          print("No URL in upload response");
          print("Full response JSON: $jsonResponse");
          print("Looking for user.profile_picture_url: ${jsonResponse['user']?['profile_picture_url']}");
          print("Looking for data.profile_picture_url: ${jsonResponse['data']?['profile_picture_url']}");
          print("Looking for profile_picture_url: ${jsonResponse['profile_picture_url']}");
          print("Looking for url: ${jsonResponse['url']}");
          return null;
        }
      } else {
        print("Upload failed with status: ${response.statusCode}");
        print("Response: $responseBody");
        return null;
      }
    } catch (e) {
      print("Error uploading profile picture: $e");
      return null;
    }
  }

  /// Delete profile picture from the database
  static Future<bool> deleteProfilePicture(String token) async {
    try {
      final url = Uri.parse("${ApiConfig.baseUrl}/profile/picture");

      final response = await http.delete(
        url,
        headers: {
          "Authorization": "Bearer $token",
          "Content-Type": "application/json",
        },
      );

      print("Delete profile picture response: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("✅ Profile picture deleted successfully");
        return true;
      } else {
        print("Failed to delete profile picture. Status: ${response.statusCode}, Body: ${response.body}");
        return false;
      }
    } catch (e) {
      print("Error deleting profile picture: $e");
      return false;
    }
  }
}
