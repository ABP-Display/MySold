import 'package:flutter/material.dart';

class IconLoader {
  // Toutes les icônes que tu peux choisir avec IconPicker
  static const List<IconData> allIcons = [
    Icons.home,
    Icons.add,
    Icons.delete,
    Icons.account_circle,
    Icons.category,
    Icons.attach_money,
    Icons.pie_chart,
    Icons.settings,
    Icons.shopping_cart,
    Icons.lock,
    Icons.person,
    Icons.notifications,
    Icons.edit,
    Icons.arrow_back,
    Icons.check,
    Icons.close,
    // ajoute ici toutes les icônes que tu utilises dynamiquement
  ];

  // Cette fonction “utilise” les icônes pour Flutter Web
  static void load() {
    for (var icon in allIcons) {
      // juste une référence, Flutter Web va les inclure
      icon.codePoint;
    }
  }
}
