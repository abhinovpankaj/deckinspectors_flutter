import '../resources/repository.dart';

class ImagesBloc {
  final Repository _repository = Repository();

  Future<Object> uploadImage(String path, String containerName, String uploader,
      String id, String parentType, String entityName) async {
    var response = await _repository.uploadImage(
        path, containerName, uploader, id, parentType, entityName);

    return response;
  }

  Future<Object> saveImageLocally(String path, String containerName,
      String uploader, String id, String parentType, String entityName) async {
    var response = await _repository.saveImageLocal(
        path, containerName, uploader, id, parentType, entityName);

    return response;
  }

  Future<List<Object>> uploadMultipleImages(
      List<String> imagePathList,
      String containerName,
      String uploader,
      String id,
      String parentType,
      String entityName) async {
    final results = await Future.wait<Object>(
      imagePathList.map(
        (element) => uploadImage(
          element, containerName, uploader, id, parentType, entityName,
        ),
      ),
    );
    return results;
  }
}

final imagesBloc = ImagesBloc();
