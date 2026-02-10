import 'package:flutter/material.dart';

// Shared robust image loading widget with retry logic
class RobustImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;
  final Duration retryDelay;
  final int maxRetries;

  const RobustImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
    this.retryDelay = const Duration(seconds: 2),
    this.maxRetries = 3,
  });

  @override
  State<RobustImage> createState() => _RobustImageState();
}

class _RobustImageState extends State<RobustImage> {
  int _retryCount = 0;
  bool _retryScheduled = false;

  @override
  void didUpdateWidget(RobustImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _retryCount = 0;
        _retryScheduled = false;
      });
    }
  }

  void _scheduleRetry() {
    if (_retryScheduled || _retryCount >= widget.maxRetries) return;
    _retryScheduled = true;
    Future.delayed(widget.retryDelay, () {
      if (!mounted) return;
      setState(() {
        _retryCount++;
        _retryScheduled = false;
      });
    });
  }

  Widget _loadingWidget() {
    return widget.placeholder ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[200],
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
  }

  Widget _errorWidget() {
    return widget.errorWidget ??
        Container(
          width: widget.width,
          height: widget.height,
          color: Colors.grey[300],
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.image_not_supported,
                size: 32,
                color: Colors.grey,
              ),
              SizedBox(height: 4),
              Text(
                'Image unavailable',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    Widget imageWidget = Image.network(
      widget.url,
      key: ValueKey('${widget.url}#$_retryCount'),
      fit: widget.fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return _loadingWidget();
      },
      errorBuilder: (context, error, stackTrace) {
        if (_retryCount < widget.maxRetries) {
          _scheduleRetry();
          return _loadingWidget();
        }

        return _errorWidget();
      },
    );

    if (widget.borderRadius != null) {
      imageWidget = ClipRRect(
        borderRadius: widget.borderRadius!,
        child: imageWidget,
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: imageWidget,
    );
  }
}
