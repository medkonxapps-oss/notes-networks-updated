import 'package:supabase_flutter/supabase_flutter.dart';

String getFriendlyErrorMessage(Object error) {
  if (error is PostgrestException) {
    // Database specific errors
    switch (error.code) {
      case '23505':
        return 'This item already exists in the collection.';
      case '42P01':
      case '42703':
        return 'Something went wrong on our end. Please try again later.';
      case '23503':
        return 'This action cannot be completed because a related record is missing.';
      case 'PGRST116':
        return 'Record not found.';
    }

    // Check for "406" or other common network/proxy errors that often manifest as PostgrestException
    if (error.message.toLowerCase().contains('failed to fetch') || 
        error.message.toLowerCase().contains('network') ||
        error.message.toLowerCase().contains('stream')) {
      return 'No internet connection. Please check your network and try again.';
    }

    // HTTP-like status codes from Postgrest
    final status = int.tryParse(error.code ?? '');
    if (status != null) {
      if (status == 401) return 'Session expired. Please sign in again.';
      if (status == 403) return 'You don\'t have permission to do this.';
      if (status == 404) return 'Resource not found.';
      if (status >= 500) return 'Server is currently busy. Please try again in a moment.';
    }

    if (error.message.contains('new row violates row-level security policy')) {
      return 'You don\'t have permission to perform this action.';
    }
    
    // Default for PostgrestException
    return 'Could not connect to server. Please check your internet.';
  }

  if (error is AuthException) {
    if (error.message.contains('Invalid login credentials')) {
      return 'Incorrect email or password. Please try again.';
    }
    if (error.message.contains('Email not confirmed')) {
      return 'Please verify your email address to continue.';
    }
    return error.message;
  }

  if (error is StorageException) {
    if (error.message.contains('Object not found')) {
      return 'The requested file was not found.';
    }
    if (error.statusCode == '403') {
      return 'Permission denied to access this file.';
    }
    return 'Storage error: ${error.message}';
  }

  final errorStr = error.toString().toLowerCase();
  if (errorStr.contains('socketexception') || 
      errorStr.contains('clientexception') ||
      errorStr.contains('network') ||
      errorStr.contains('connection') ||
      errorStr.contains('handshake') ||
      errorStr.contains('failed host lookup')) {
    return 'No internet connection. Please check your network and try again.';
  }
  
  String msg = error.toString();
  if (msg.startsWith('Exception: ')) {
    msg = msg.substring(11);
  }
  
  // Strip common technical prefix
  if (msg.contains('PostgrestException:')) {
    msg = msg.split('PostgrestException:').last.trim();
  }
  
  return msg;
}
