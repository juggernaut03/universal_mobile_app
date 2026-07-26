// lib/presentation/widgets/search_widget.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:patelmart/core/utils/input_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/auth_providers.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/search_providers.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';


class SearchWidget extends ConsumerStatefulWidget {
  final Function(String)? onSearch;
  final TextEditingController? controller;
  final bool showSuggestions;
  final String hintText;
  final bool enabled;

  const SearchWidget({
    Key? key,
    this.onSearch,
    this.controller,
    this.showSuggestions = true,
    this.hintText = 'Search for products',
    this.enabled = true,
  }) : super(key: key);

  @override
  ConsumerState<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends ConsumerState<SearchWidget> {
  late TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  
  List<dynamic> _suggestions = [];
  bool _isLoading = false;
  Timer? _debounceTimer;
  
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  static const int _minSearchLength = 2;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.showSuggestions) {
        if (_controller.text.length >= _minSearchLength) {
          _showOverlay();
        }
      } else {
        _hideOverlay();
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode.dispose();
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onTextChanged(String query) {
    _debounceTimer?.cancel();
    
    if (query.length >= _minSearchLength && widget.showSuggestions) {
      setState(() {
        _isLoading = true;
      });
      
      _debounceTimer = Timer(_debounceDuration, () {
        _fetchSuggestions(query);
      });
      
      if (_focusNode.hasFocus) {
        _showOverlay();
      }
    } else {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      _hideOverlay();
    }
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!mounted) return;
    
    try {
      final selectedOutlet = ref.read(selectedOutletProvider).valueOrNull;
      final storeCode = selectedOutlet?.storeCode ?? 'TTL';
      
      final apiClient = ref.read(apiClientProvider);
      
      final response = await apiClient.post(
        ApiConstants.searchProducts,
        body: {
          'search_term': query,
          'store_code': storeCode,
        },
      );

      if (!mounted) return;

      List<dynamic> suggestions = [];
      if (response is Map && response['data'] is List) {
        suggestions = (response['data'] as List).take(5).toList();
      } else if (response is List) {
        suggestions = response.take(5).toList();
      }
      
      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
      
      if (_focusNode.hasFocus && suggestions.isNotEmpty) {
        _showOverlay();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _getTextFieldWidth(),
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.2)),
              ),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  double _getTextFieldWidth() {
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    return renderBox?.size.width ?? 300;
  }

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'No suggestions found',
          style: TextStyle(color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: _suggestions.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final suggestion = _suggestions[index];
        final productName = suggestion['product_name'] ?? 'Unknown Product';
        final productImage = suggestion['pcode_img'] ?? '';
        final pCode = suggestion['p_code'] ?? '';
        
        return ListTile(
          dense: true,
          leading: SizedBox(
            width: 40,
            height: 40,
            child: productImage.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      productImage,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.image_not_supported_outlined),
                    ),
                  )
                : const Icon(Icons.search, color: Colors.grey),
          ),
          title: Text(
            productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14),
          ),
          onTap: () {
            _controller.text = productName;
            _hideOverlay();
            _focusNode.unfocus();
            
            if (pCode.isNotEmpty) {
              // Save to search history
              ref.read(searchHistoryProvider.notifier).addSearchQuery(
                productName,
                productId: pCode,
                productName: productName,
              );
              // Navigate directly to product
              context.push('/product/$pCode');
            } else if (widget.onSearch != null) {
              widget.onSearch!(productName);
            }
          },
        );
      },
    );
  }

  void _onSubmitted(String query) {
    _hideOverlay();
    _focusNode.unfocus();
    
    if (query.isNotEmpty) {
      // Save to search history
      ref.read(searchHistoryProvider.notifier).addSearchQuery(query);
      
      if (widget.onSearch != null) {
        widget.onSearch!(query);
      } else {
        // Default behavior: navigate to search screen
        context.push('/search?query=${Uri.encodeComponent(query)}');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        height: 46,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              spreadRadius: 0,
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          onChanged: _onTextChanged,
          onSubmitted: _onSubmitted,
          textInputAction: TextInputAction.search,
          inputFormatters: [NoEmojiInputFormatter()],
          textAlign: TextAlign.start, // Ensure text starts from left when typing
          decoration: InputDecoration(
            hintText: widget.hintText,
            hintStyle: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
            prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _suggestions = [];
                        _isLoading = false;
                      });
                      _hideOverlay();
                    },
                  )
                : null,
            border: InputBorder.none,
            // Updated content padding for better vertical centering
            contentPadding: const EdgeInsets.symmetric(
              vertical: 13.0, // Increased for better centering
              horizontal: 0.0,
            ),
            // Add these properties for better alignment
            isDense: false,
            alignLabelWithHint: true,
          ),
          style: const TextStyle(
            fontSize: 12,
            height: 1.3, // Line height for better vertical alignment
          ),
        ),
      ),
    );
  }
}