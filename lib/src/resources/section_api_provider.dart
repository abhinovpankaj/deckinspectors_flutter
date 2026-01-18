import 'dart:convert';
import 'package:http/http.dart' show Client;
import '../models/error_response.dart';
import '../models/section_model.dart';
import '../models/success_response.dart';
import 'urls.dart';

class SectionsApiProvider {
  Client client = Client();

  Future<SectionResponse> getSection(String id) async {
    var endPoint = URLS.manageSectionUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final response = await client.get(baseUrl);

    if (response.statusCode == 201) {
      return SectionResponse.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to get section');
    }
  }

  Future<Object> addSection(VisualSection visualSection) async {
    var endPoint = '${URLS.manageSectionUrl}add';
    final baseUrl = Uri.parse(endPoint);
    final sectionObject = jsonEncode({
      'name': visualSection.name,
      'exteriorelements': visualSection.exteriorelements,
      'waterproofingelements': visualSection.waterproofingelements,
      'additionalconsiderations': visualSection.additionalconsiderations,
      'visualreview': visualSection.visualreview,
      'visualsignsofleak': visualSection.visualsignsofleak,
      'furtherinvasivereviewrequired':
          visualSection.furtherinvasivereviewrequired,
      'conditionalassessment': visualSection.conditionalassessment,
      'eee': visualSection.eee,
      'lbc': visualSection.lbc,
      'awe': visualSection.awe,
      'createdby': visualSection.createdby,
      'parentid': visualSection.parentid,
    });
    final response = await client.post(
      baseUrl,
      body: sectionObject,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  Future<Object> updateSection(VisualSection visualSection, String id) async {
    var endPoint = URLS.manageSectionUrl + id;
    final baseUrl = Uri.parse(endPoint);
    final sectionObject = jsonEncode({
      'name': visualSection.name,
      'exteriorelements': visualSection.exteriorelements,
      'waterproofingelements': visualSection.waterproofingelements,
      'additionalconsiderations': visualSection.additionalconsiderations,
      'visualreview': visualSection.visualreview,
      'visualsignsofleak': visualSection.visualsignsofleak,
      'furtherinvasivereviewrequired':
          visualSection.furtherinvasivereviewrequired,
      'conditionalassessment': visualSection.conditionalassessment,
      'eee': visualSection.eee,
      'lbc': visualSection.lbc,
      'awe': visualSection.awe,
      'lasteditedby': visualSection.lasteditedby,
      'parentid': visualSection.parentid,
    });
    final response = await client.put(
      baseUrl,
      body: sectionObject,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }

  deleteSection(Object requestBody, String id) async {
    var endPoint = '${URLS.manageSectionUrl}id/toggleVisibility';
    final baseUrl = Uri.parse(endPoint);
    final response = await client.post(
      baseUrl,
      body: requestBody,
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 201) {
      return SuccessResponse.fromJson(json.decode(response.body));
    } else {
      return ErrorResponse.fromJson(json.decode(response.body));
    }
  }
}
