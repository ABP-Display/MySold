import 'package:flutter/material.dart';

class ProfileButton extends StatelessWidget {
  final VoidCallback onPressed;
  const ProfileButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(icon: const Icon(Icons.person), onPressed: onPressed);
  }
}
