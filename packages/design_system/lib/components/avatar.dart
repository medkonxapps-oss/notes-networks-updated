import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../tokens/colors.dart';

class AppAvatar extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;
  final bool isVerified;
  final VoidCallback? onTap;

  /// If true, tapping the avatar (when imageUrl is set) opens a full-screen
  /// WhatsApp-style viewer. Set [onTap] to override this behaviour.
  final bool enableFullScreenView;

  const AppAvatar({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 40,
    this.isVerified = false,
    this.onTap,
    this.enableFullScreenView = false,
  });

  /// Strip the cache-busting `?t=` timestamp from the URL so that
  /// CachedNetworkImage uses a stable cache key, but still fetches
  /// the latest image when the URL base changes (e.g. after re-upload).
  /// Public so callers can evict the cache after an avatar update.
  static String cacheKeyFor(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    // Remove only the `t` query param; keep everything else
    final params = Map<String, String>.from(uri.queryParameters)..remove('t');
    return uri.replace(queryParameters: params.isEmpty ? null : params).toString();
  }

  @override
  Widget build(BuildContext context) {
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w[0]).take(2).join().toUpperCase()
        : '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    void handleTap() {
      if (onTap != null) {
        onTap!();
      } else if (enableFullScreenView && hasImage) {
        _openFullScreen(context, imageUrl!, name);
      }
    }

    return GestureDetector(
      onTap: (onTap != null || (enableFullScreenView && hasImage)) ? handleTap : null,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? const Color(0xFF2D2D4D) : AppColors.primarySurface,
            ),
            child: ClipOval(
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: imageUrl!,
                      // Stable cache key — ignores the ?t= timestamp so we
                      // don't accumulate thousands of cached copies.
                      
                      fit: BoxFit.cover,
                      // No auth header — avatars bucket is public
                      httpHeaders: const {},
                      placeholder: (_, __) => _placeholder(initials, size),
                      errorWidget: (_, __, ___) => _placeholder(initials, size),
                    )
                  : _placeholder(initials, size),
            ),
          ),
          if (isVerified)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: const BoxDecoration(
                  color: AppColors.verified,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.verified, color: Colors.white, size: size * 0.2),
              ),
            ),
        ],
      ),
    );
  }

  static void _openFullScreen(BuildContext context, String imageUrl, String name) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => _FullScreenAvatarView(
          imageUrl: imageUrl,
          name: name,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Public entry point for opening the full-screen viewer from outside the widget.
  static void openFullScreenStatic(BuildContext context, String imageUrl, String name) =>
      _openFullScreen(context, imageUrl, name);

  static Widget _placeholder(String initials, double size) => Center(
        child: initials.isEmpty
            ? Icon(Icons.person_rounded, size: size * 0.5, color: AppColors.primary)
            : Text(
                initials,
                style: TextStyle(
                  fontSize: size * 0.35,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
      );
}

/// WhatsApp-style full-screen profile picture viewer.
class _FullScreenAvatarView extends StatelessWidget {
  final String imageUrl;
  final String name;

  const _FullScreenAvatarView({required this.imageUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          name,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 4.0,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            
            httpHeaders: const {},
            fit: BoxFit.contain,
            placeholder: (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            errorWidget: (_, __, ___) => const Center(
              child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}
