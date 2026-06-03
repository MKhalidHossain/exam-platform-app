class ApiResponse<T> {
  final bool success;
  final String? message;
  final String? code;
  final T? data;
  final dynamic rawData;
  final dynamic error;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.code,
    this.data,
    this.rawData,
    this.error,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] ?? false,
      message: json['message'],
      code: json['code']?.toString(),
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      rawData: json['data'],
      error: json['error'],
      statusCode: json['statusCode'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'message': message,
      'code': code,
      'data': data,
      'rawData': rawData,
      'error': error,
      'statusCode': statusCode,
    };
  }
}
