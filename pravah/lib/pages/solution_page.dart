import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/gestures.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';


class SolutionPage extends StatefulWidget {
  final String imageUrl;

  const SolutionPage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  State<SolutionPage> createState() => _SolutionPageState();
}

class _SolutionPageState extends State<SolutionPage> {
  LatLng? coordinates;
  String generatedText = "Processing...";
  bool isLoading = true;
  bool isError = false;
  final String geminiApiKey = dotenv.env['AI_API_KEY'] ?? ''; // Replace with your actual API key

  @override
  void initState() {
    super.initState();
    _initializeSolution();
  }

  Future<void> _initializeSolution() async {
    try {
      final content = await generateContent(widget.imageUrl);
      setState(() {
        generatedText = content;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        generatedText = "Error: $e";
        isLoading = false;
        isError = true;
      });
    }
  }

  Future<String> generateContent(String imageUrl) async {
    final Uri url = Uri.parse(
        "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=$geminiApiKey"
    );

    // Convert image to base64 if it's a local file
    String base64Image = '';
    String mimeType = '';

    if (imageUrl.startsWith('http')) {
      // For network images, fetch the image first
      try {
        final imageResponse = await http.get(Uri.parse(imageUrl));
        if (imageResponse.statusCode == 200) {
          base64Image = base64Encode(imageResponse.bodyBytes);
          // Determine MIME type based on URL extension or response headers
          if (imageUrl.toLowerCase().endsWith('.jpg') || imageUrl.toLowerCase().endsWith('.jpeg')) {
            mimeType = 'image/jpeg';
          } else if (imageUrl.toLowerCase().endsWith('.png')) {
            mimeType = 'image/png';
          } else {
            // Default to JPEG if we can't determine
            mimeType = 'image/jpeg';
          }
        } else {
          return "Error: Failed to fetch image. Status code: ${imageResponse.statusCode}";
        }
      } catch (e) {
        return "Error fetching image: $e";
      }
    } else {
      // For local files
      try {
        final File imageFile = File(imageUrl);
        final bytes = await imageFile.readAsBytes();
        base64Image = base64Encode(bytes);

        // Determine MIME type based on file extension
        if (imageUrl.toLowerCase().endsWith('.jpg') || imageUrl.toLowerCase().endsWith('.jpeg')) {
          mimeType = 'image/jpeg';
        } else if (imageUrl.toLowerCase().endsWith('.png')) {
          mimeType = 'image/png';
        } else {
          // Default to JPEG if we can't determine
          mimeType = 'image/jpeg';
        }
      } catch (e) {
        return "Error reading image file: $e";
      }
    }

    Map<String, dynamic> requestBody = {
      "contents": [
        {
          "role": "user",
          "parts": [
            {
              "inlineData": {
                "mimeType": mimeType,
                "data": base64Image
              }
            },
            {
              "text": "Identify the waste and categorize it. Provide three to four pointers under Recycle, Reuse, and Reduce. If it is a living object, return 'Content cannot be generated for this object'"
            }
          ]
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        return jsonResponse["candidates"]?[0]["content"]?["parts"]?[0]["text"] ?? "No content generated.";
      } else {
        return "Error: Failed to generate content. Status code: ${response.statusCode}\nResponse: ${response.body}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: MediaQuery.of(context).size.height * 0.075,
        title: Text(
          "Solution",
          style: GoogleFonts.comfortaa(
            fontSize: MediaQuery.of(context).size.height * 0.04,
            color: const Color(0xFFF5F5DC), // Cream color for text
          ),
        ),
        backgroundColor: const Color(0xFF0B2732), // Dark blue for AppBar
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF0B2732), // Dark blue background
              ),
            ),
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),

                  // 📌 Image Display
                  _buildImagePreview(),

                  const SizedBox(height: 20),

                  // 📌 AI Generated Content
                  _buildGeneratedContent(),

                  const SizedBox(height: 20),

                  // Additional content (if needed)
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.all(15),
      height: MediaQuery.of(context).size.height * 0.3,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF5F5DC), // Cream color for container
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: widget.imageUrl.startsWith("http")
            ? Image.network(
          widget.imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0B2732)),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.error,
              color: Color(0xFF0B2732),
              size: 50,
            );
          },
        )
            : Image.file(File(widget.imageUrl), fit: BoxFit.cover),
      ),
    );
  }

  Widget _buildGeneratedContent() {
    return Container(
      alignment: Alignment.center,
      margin: const EdgeInsets.all(15),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xFFF5F5DC), // Cream color for container
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: isLoading
            ? Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0B2732)),
            ),
            const SizedBox(height: 20),
            Text(
              "Analyzing image and generating recommendations...",
              style: GoogleFonts.montserrat(
                fontSize: MediaQuery.of(context).size.height * 0.018,
                color: const Color(0xFF0B2732),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        )
            : Text(
          generatedText,
          style: GoogleFonts.montserrat(
            fontSize: MediaQuery.of(context).size.height * 0.02,
            color: const Color(0xFF0B2732), // Dark blue text on cream background
          ),
          textAlign: TextAlign.left,
        ),
      ),
    );
  }
}