import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../theme/haychat_theme.dart';

class HayScaffold extends StatelessWidget {
  const HayScaffold({
    required this.child,
    super.key,
    this.bottomNavigationBar,
    this.floatingActionButton,
    this.resizeToAvoidBottomInset = true,
    this.padding = const EdgeInsets.fromLTRB(22, 8, 22, 22),
  });

  final Widget child;
  final Widget? bottomNavigationBar;
  final Widget? floatingActionButton;
  final bool resizeToAvoidBottomInset;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      backgroundColor: HayColors.page,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButton: floatingActionButton,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [HayColors.deep, HayColors.page],
            stops: [0, 0.72],
          ),
        ),
        child: SafeArea(
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class HayLogo extends StatelessWidget {
  const HayLogo({super.key, this.size = 68, this.showWordmark = true});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * .28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [HayColors.emeraldBright, HayColors.emerald],
            ),
            border: Border.all(color: HayColors.hairlineSoft),
            boxShadow: const [
              BoxShadow(
                color: Color(0x594C7A5C),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            color: HayColors.ivory,
            size: size * .45,
          ),
        ),
        if (showWordmark) ...[
          const SizedBox(height: 18),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                  text: 'Hay',
                  style: TextStyle(color: HayColors.ivoryDim),
                ),
                TextSpan(
                  text: 'Chat',
                  style: TextStyle(
                    color: HayColors.goldSoft,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            style: const TextStyle(
              fontFamily: HayTheme.displayFont,
              fontSize: 28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class HayBackButton extends StatelessWidget {
  const HayBackButton({super.key, this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        alignment: Alignment.centerLeft,
        onPressed: onPressed ?? () => Navigator.of(context).pop(),
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: HayColors.ivoryDim,
        ),
      ),
    );
  }
}

class HayTitle extends StatelessWidget {
  const HayTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class HayField extends StatelessWidget {
  const HayField({
    required this.label,
    super.key,
    this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: HayColors.gold,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          cursorColor: HayColors.gold,
          style: const TextStyle(color: HayColors.ivory, fontSize: 13),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class HayPrimaryButton extends StatelessWidget {
  const HayPrimaryButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: onPressed == null
              ? const LinearGradient(
                  colors: [HayColors.elevated, HayColors.card],
                )
              : const LinearGradient(
                  colors: [HayColors.goldSoft, HayColors.gold],
                ),
          boxShadow: onPressed == null
              ? null
              : const [
                  BoxShadow(
                    color: Color(0x55C6A15B),
                    blurRadius: 20,
                    offset: Offset(0, 9),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: const Color(0xFF23180B)),
                  const SizedBox(width: 8),
                ],
                Text(label, style: Theme.of(context).textTheme.labelLarge),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HayAvatar extends StatelessWidget {
  const HayAvatar({
    required this.initials,
    super.key,
    this.size = 46,
    this.online = false,
    this.imageBytes,
    this.photoUrl = '',
  });

  final String initials;
  final double size;
  final bool online;
  final Uint8List? imageBytes;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [HayColors.emeraldBright, HayColors.emerald],
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: HayColors.goldSoft,
          fontFamily: HayTheme.displayFont,
          fontStyle: FontStyle.italic,
          fontSize: size * .33,
        ),
      ),
    );

    final Widget picture;
    if (imageBytes != null && imageBytes!.isNotEmpty) {
      picture = Image.memory(
        imageBytes!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (photoUrl.trim().isNotEmpty) {
      picture = Image.network(
        photoUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback,
      );
    } else {
      picture = fallback;
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * .3),
          child: SizedBox(width: size, height: size, child: picture),
        ),
        if (online)
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(
                color: HayColors.sage,
                shape: BoxShape.circle,
                border: Border.all(color: HayColors.deep, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class HaySearchField extends StatelessWidget {
  const HaySearchField({required this.hint, super.key, this.onChanged});

  final String hint;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      cursorColor: HayColors.gold,
      style: const TextStyle(color: HayColors.ivory, fontSize: 13),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class Hairline extends StatelessWidget {
  const Hairline({super.key});

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, color: HayColors.hairlineSoft);
}
