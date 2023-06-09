
class SuccessResponse {
    String? id;
    String? message;
    int? code;

    SuccessResponse({this.id, this.message, this.code}); 

    SuccessResponse.fromJson(Map<String, dynamic> json) {
        id = json['id'];
        message = json['message'];
        code = json['code'];
    }

    Map<String, dynamic> toJson() {
        final Map<String, dynamic> data = <String, dynamic>{};
        data['id'] = id;
        data['message'] = message;
        data['code'] = code;
        return data;
    }
}

class ImageResponse {
    String? url;
    String? message;   

    ImageResponse({ this.message, this.url}); 

    ImageResponse.fromJson(Map<String, dynamic> json) {
       
        message = json['message'];
        url = json['url'];
    }

    Map<String, dynamic> toJson() {
        final Map<String, dynamic> data = <String, dynamic>{};
        
        data['message'] = message;
        data['url'] = url;
        return data;
    }
}

// class SuccessResponse {
//     Data? data;

//     SuccessResponse({this.data}); 

//     SuccessResponse.fromJson(Map<String, dynamic> json) {
//         data = json['data'] != null ? Data?.fromJson(json['data']) : null;
//     }

//     Map<String, dynamic> toJson() {
//         final Map<String, dynamic> dataMap = <String, dynamic>{};
//         dataMap['data'] = data!.toJson();
//         return dataMap;
//     }
// }

