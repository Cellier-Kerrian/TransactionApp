import 'package:flutter/material.dart';

// Modifie ta classe pour accepter une fonction onBack
class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  // ... tes autres champs existants
  final VoidCallback? onBack; // <-- Ajoute ceci

  const AppTopBar({
    super.key,
    // ... tes autres paramètres
    this.onBack, // <-- Ajoute ceci au constructeur
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // Si onBack existe, on affiche la flèche retour, sinon null (ou ton logo/menu par défaut)
      leading: onBack != null
          ? IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      )
          : null, // ou ton leading habituel

      title: const Text("Transaction App"), // Ton titre habituel
      actions: [
        // ... tes boutons paramètres existants
        IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            // ... ta logique settings
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}