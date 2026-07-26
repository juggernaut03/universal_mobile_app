// lib/core/widgets/quantity_input_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantityInputWidget extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final int minQuantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;
  final double height;
  final double width;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle? textStyle;
  final bool enabled;
  final bool showBorder;
  final BorderRadius? borderRadius;

  const QuantityInputWidget({
    Key? key,
    required this.initialQuantity,
    required this.onQuantityChanged,
    required this.onDecrement,
    required this.onIncrement,
    this.maxQuantity = 99,
    this.minQuantity = 1,
    this.height = 36,
    this.width = double.infinity,
    this.primaryColor = Colors.blue,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.grey,
    this.textStyle,
    this.enabled = true,
    this.showBorder = true,
    this.borderRadius,
  }) : super(key: key);

  @override
  State<QuantityInputWidget> createState() => _QuantityInputWidgetState();
}

class _QuantityInputWidgetState extends State<QuantityInputWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuantity.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(QuantityInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity && !_isEditing) {
      _controller.text = widget.initialQuantity.toString();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isEditing = _focusNode.hasFocus;
    });
    
    if (!_focusNode.hasFocus) {
      _validateAndUpdateQuantity();
    }
  }

  void _validateAndUpdateQuantity() {
    final text = _controller.text.trim();
    final quantity = int.tryParse(text);
    
    if (quantity == null || quantity < widget.minQuantity) {
      // Reset to minimum quantity if invalid
      _controller.text = widget.minQuantity.toString();
      widget.onQuantityChanged(widget.minQuantity);
    } else if (quantity > widget.maxQuantity) {
      // Limit to maximum quantity
      _controller.text = widget.maxQuantity.toString();
      widget.onQuantityChanged(widget.maxQuantity);
      _showMaxQuantityWarning();
    } else {
      // Valid quantity
      widget.onQuantityChanged(quantity);
    }
  }

  void _showMaxQuantityWarning() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum ${widget.maxQuantity} items allowed'),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _handleDecrement() {
    if (!widget.enabled) return;
    
    final currentQuantity = int.tryParse(_controller.text) ?? widget.initialQuantity;
    if (currentQuantity > widget.minQuantity) {
      final newQuantity = currentQuantity - 1;
      _controller.text = newQuantity.toString();
      widget.onQuantityChanged(newQuantity);
    }
    widget.onDecrement();
  }

  void _handleIncrement() {
    if (!widget.enabled) return;
    
    final currentQuantity = int.tryParse(_controller.text) ?? widget.initialQuantity;
    if (currentQuantity < widget.maxQuantity) {
      final newQuantity = currentQuantity + 1;
      _controller.text = newQuantity.toString();
      widget.onQuantityChanged(newQuantity);
    } else {
      _showMaxQuantityWarning();
    }
    widget.onIncrement();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(4);
    final textStyle = widget.textStyle ?? const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        border: widget.showBorder ? Border.all(color: widget.borderColor.withOpacity(0.3)) : null,
      ),
      child: Row(
        children: [
          // Decrement button
          _buildControlButton(
            icon: Icons.remove,
            onTap: _handleDecrement,
            isLeft: true,
            borderRadius: borderRadius,
          ),
          
          // Quantity input field
          Expanded(
            child: Container(
              height: widget.height,
              alignment: Alignment.center,
              color: widget.backgroundColor,
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: widget.maxQuantity.toString().length,
                style: textStyle.copyWith(
                  color: widget.enabled ? textStyle.color : Colors.grey,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  counterText: '', // Hide character counter
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
                ],
                onSubmitted: (_) => _validateAndUpdateQuantity(),
                onTap: () {
                  // Select all text when tapped
                  _controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _controller.text.length,
                  );
                },
              ),
            ),
          ),
          
          // Increment button
          _buildControlButton(
            icon: Icons.add,
            onTap: _handleIncrement,
            isLeft: false,
            borderRadius: borderRadius,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isLeft,
    required BorderRadius borderRadius,
  }) {
    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Container(
        width: 30,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.enabled ? widget.primaryColor : Colors.grey.shade300,
          borderRadius: isLeft 
            ? BorderRadius.only(
                topLeft: borderRadius.topLeft,
                bottomLeft: borderRadius.bottomLeft,
              )
            : BorderRadius.only(
                topRight: borderRadius.topRight,
                bottomRight: borderRadius.bottomRight,
              ),
        ),
        child: Icon(
          icon,
          color: widget.enabled ? Colors.white : Colors.grey.shade600,
          size: 16,
        ),
      ),
    );
  }
}

// Enhanced version with more customization options
class AdvancedQuantityInputWidget extends StatefulWidget {
  final int initialQuantity;
  final int maxQuantity;
  final int minQuantity;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final ValueChanged<int>? onMaxQuantityReached;
  final ValueChanged<int>? onMinQuantityReached;
  final double height;
  final double? width;
  final Color primaryColor;
  final Color backgroundColor;
  final Color borderColor;
  final TextStyle? textStyle;
  final bool enabled;
  final bool showBorder;
  final BorderRadius? borderRadius;
  final String? label;
  final String? helperText;
  final bool showLabel;
  final bool allowZero;
  final IconData? decrementIcon;
  final IconData? incrementIcon;
  final EdgeInsetsGeometry? padding;

  const AdvancedQuantityInputWidget({
    Key? key,
    required this.initialQuantity,
    required this.onQuantityChanged,
    this.onDecrement,
    this.onIncrement,
    this.onMaxQuantityReached,
    this.onMinQuantityReached,
    this.maxQuantity = 99,
    this.minQuantity = 1,
    this.height = 36,
    this.width,
    this.primaryColor = Colors.blue,
    this.backgroundColor = Colors.white,
    this.borderColor = Colors.grey,
    this.textStyle,
    this.enabled = true,
    this.showBorder = true,
    this.borderRadius,
    this.label,
    this.helperText,
    this.showLabel = false,
    this.allowZero = false,
    this.decrementIcon = Icons.remove,
    this.incrementIcon = Icons.add,
    this.padding,
  }) : super(key: key);

  @override
  State<AdvancedQuantityInputWidget> createState() => _AdvancedQuantityInputWidgetState();
}

class _AdvancedQuantityInputWidgetState extends State<AdvancedQuantityInputWidget> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isEditing = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialQuantity.toString());
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(AdvancedQuantityInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialQuantity != widget.initialQuantity && !_isEditing) {
      _controller.text = widget.initialQuantity.toString();
      setState(() {
        _errorText = null;
      });
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    setState(() {
      _isEditing = _focusNode.hasFocus;
    });
    
    if (!_focusNode.hasFocus) {
      _validateAndUpdateQuantity();
    }
  }

  void _validateAndUpdateQuantity() {
    final text = _controller.text.trim();
    final quantity = int.tryParse(text);
    
    setState(() {
      _errorText = null;
    });
    
    if (quantity == null) {
      setState(() {
        _errorText = 'Please enter a valid number';
      });
      _controller.text = widget.initialQuantity.toString();
      return;
    }
    
    final minQuantity = widget.allowZero ? 0 : widget.minQuantity;
    
    if (quantity < minQuantity) {
      setState(() {
        _errorText = 'Minimum quantity is $minQuantity';
      });
      _controller.text = minQuantity.toString();
      widget.onQuantityChanged(minQuantity);
      widget.onMinQuantityReached?.call(minQuantity);
    } else if (quantity > widget.maxQuantity) {
      setState(() {
        _errorText = 'Maximum quantity is ${widget.maxQuantity}';
      });
      _controller.text = widget.maxQuantity.toString();
      widget.onQuantityChanged(widget.maxQuantity);
      widget.onMaxQuantityReached?.call(widget.maxQuantity);
    } else {
      // Valid quantity
      widget.onQuantityChanged(quantity);
    }
  }

  void _handleDecrement() {
    if (!widget.enabled) return;
    
    final currentQuantity = int.tryParse(_controller.text) ?? widget.initialQuantity;
    final minQuantity = widget.allowZero ? 0 : widget.minQuantity;
    
    if (currentQuantity > minQuantity) {
      final newQuantity = currentQuantity - 1;
      _controller.text = newQuantity.toString();
      widget.onQuantityChanged(newQuantity);
      setState(() {
        _errorText = null;
      });
    } else {
      widget.onMinQuantityReached?.call(minQuantity);
    }
    widget.onDecrement?.call();
  }

  void _handleIncrement() {
    if (!widget.enabled) return;
    
    final currentQuantity = int.tryParse(_controller.text) ?? widget.initialQuantity;
    if (currentQuantity < widget.maxQuantity) {
      final newQuantity = currentQuantity + 1;
      _controller.text = newQuantity.toString();
      widget.onQuantityChanged(newQuantity);
      setState(() {
        _errorText = null;
      });
    } else {
      widget.onMaxQuantityReached?.call(widget.maxQuantity);
    }
    widget.onIncrement?.call();
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = widget.borderRadius ?? BorderRadius.circular(4);
    final textStyle = widget.textStyle ?? const TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label
          if (widget.showLabel && widget.label != null) ...[
            Text(
              widget.label!,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
          ],
          
          // Quantity input widget
          Container(
            height: widget.height,
            width: widget.width,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: widget.showBorder 
                ? Border.all(
                    color: _errorText != null 
                      ? Colors.red 
                      : widget.borderColor.withOpacity(0.3)
                  ) 
                : null,
            ),
            child: Row(
              children: [
                // Decrement button
                _buildControlButton(
                  icon: widget.decrementIcon!,
                  onTap: _handleDecrement,
                  isLeft: true,
                  borderRadius: borderRadius,
                ),
                
                // Quantity input field
                Expanded(
                  child: Container(
                    height: widget.height,
                    alignment: Alignment.center,
                    color: widget.backgroundColor,
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: widget.enabled,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: widget.maxQuantity.toString().length,
                      style: textStyle.copyWith(
                        color: widget.enabled ? textStyle.color : Colors.grey,
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        counterText: '', // Hide character counter
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(widget.maxQuantity.toString().length),
                      ],
                      onSubmitted: (_) => _validateAndUpdateQuantity(),
                      onTap: () {
                        // Select all text when tapped
                        _controller.selection = TextSelection(
                          baseOffset: 0,
                          extentOffset: _controller.text.length,
                        );
                      },
                    ),
                  ),
                ),
                
                // Increment button
                _buildControlButton(
                  icon: widget.incrementIcon!,
                  onTap: _handleIncrement,
                  isLeft: false,
                  borderRadius: borderRadius,
                ),
              ],
            ),
          ),
          
          // Error text or helper text
          if (_errorText != null || widget.helperText != null) ...[
            const SizedBox(height: 4),
            Text(
              _errorText ?? widget.helperText!,
              style: TextStyle(
                fontSize: 12,
                color: _errorText != null ? Colors.red : Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isLeft,
    required BorderRadius borderRadius,
  }) {
    return GestureDetector(
      onTap: widget.enabled ? onTap : null,
      child: Container(
        width: 30,
        height: widget.height,
        decoration: BoxDecoration(
          color: widget.enabled ? widget.primaryColor : Colors.grey.shade300,
          borderRadius: isLeft 
            ? BorderRadius.only(
                topLeft: borderRadius.topLeft,
                bottomLeft: borderRadius.bottomLeft,
              )
            : BorderRadius.only(
                topRight: borderRadius.topRight,
                bottomRight: borderRadius.bottomRight,
              ),
        ),
        child: Icon(
          icon,
          color: widget.enabled ? Colors.white : Colors.grey.shade600,
          size: 16,
        ),
      ),
    );
  }
}