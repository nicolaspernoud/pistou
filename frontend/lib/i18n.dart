import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show SynchronousFuture;

String tr(context, String str) {
  return MyLocalizations.of(context)!.tr(str);
}

class MyLocalizations {
  MyLocalizations(this.locale);

  final Locale locale;

  static MyLocalizations? of(BuildContext context) {
    return Localizations.of<MyLocalizations>(context, MyLocalizations);
  }

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      "answer": "Answer",
      "bad_response_code": "Bad server response code",
      "confirm_your_id": "Please confirm your identity...",
      "current_step": "Current step",
      "edit_step": "Edit step",
      "edit_user": "Edit user",
      "enable_log": "Enable logging",
      "get_latest_release": "Get latest release from GitHub",
      "give_answer": "Give your answer",
      "going_next_step": "Going to next step...",
      "gps_error": "Error getting position from GPS!",
      "hostname": "Hostname",
      "is_end": "Is the last step (success) ?",
      "latitude": "Latitude",
      "location_hint": "Location hint",
      "longitude": "Longitude",
      "name": "Name",
      "new_step": "New step",
      "new_user": "New user",
      "no_more_steps": "No more steps !",
      "no_users": "No users",
      "password": "Password",
      "please_enter_some_text": "Please enter some text.",
      "question": "Question",
      "rank": "Rank",
      "settings": "Settings",
      "sound_speed": "Sound reading speed",
      "sound": "Sound",
      "starting_game": "Starting game!",
      "step_created": "Step created",
      "step_deleted": "Step deleted",
      "steps": "Steps",
      "submit": "Submit",
      "token": "Admin token (for admin mode)",
      "user_created": "User created",
      "user_deleted": "User deleted",
      "user": "User",
      "username": "User name",
      "users_refreshed": "Users refreshed",
      "users": "Users",
      "wrong_answer": "Wrong answer!",
      "wrong_password": "Wrong password!",
    },
    'fr': {
      "answer": "R??ponse",
      "bad_response_code": "Mauvais code de r??ponse serveur",
      "confirm_your_id": "Veuillez confirmer votre identit??...",
      "current_step": "??tape en cours",
      "edit_step": "??diter ??tape",
      "edit_user": "??diter utilisateur",
      "enable_log": "Activer le journal",
      "get_latest_release": "R??cup??rer la derni??re version sur GitHub",
      "give_answer": "Donner votre r??ponse",
      "going_next_step": "Passage ?? l'??tape suivante...",
      "gps_error": "Erreur lors de la d??termination de la position GPS !",
      "hostname": "Serveur",
      "is_end": "Est la derni??re ??tape (succ??s) ?",
      "latitude": "Latitude",
      "location_hint": "Indice sur l'endroit",
      "longitude": "Longitude",
      "name": "Nom",
      "new_step": "Nouvelle ??tape",
      "new_user": "Nouvel utilisateur",
      "no_more_steps": "Pas d'??tape suivante",
      "no_users": "Aucun utilisateur",
      "password": "Mot de passe",
      "please_enter_some_text": "Veuillez entrer un texte.",
      "question": "Question",
      "rank": "Rang de l'??tape",
      "settings": "Param??tres",
      "sound_speed": "Vitesse de lecture du son",
      "sound": "Son",
      "starting_game": "D??marrage du jeu !",
      "step_created": "??tape cr????e",
      "step_deleted": "??tape supprim??e",
      "steps": "??tapes",
      "submit": "Valider",
      "token": "Jeton du mode administrateur",
      "user_created": "Utilisateur cr????",
      "user_deleted": "Utilisateur supprim??",
      "user": "Utilisateur",
      "username": "Nom d'utilisateur",
      "users_refreshed": "Utilisateurs rafra??chis",
      "users": "Utilisateurs",
      "wrong_answer": "Mauvaise r??ponse !",
      "wrong_password": "Mot de passe incorrect !",
    },
  };

  String tr(String token) {
    return _localizedValues[locale.languageCode]![token] ?? token;
  }

  String wrongPlace(double distance) {
    if (locale.languageCode == 'fr') {
      return "Vous ??tes ?? ${distance.round()} m??tres de l'objectif.";
    }
    return "You are at ${distance.round()} meters from the objective.";
  }
}

class MyLocalizationsDelegate extends LocalizationsDelegate<MyLocalizations> {
  const MyLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'fr'].contains(locale.languageCode);

  @override
  Future<MyLocalizations> load(Locale locale) {
    // Returning a SynchronousFuture here because an async 'load' operation
    // isn't needed to produce an instance of MyLocalizations.
    return SynchronousFuture<MyLocalizations>(MyLocalizations(locale));
  }

  @override
  bool shouldReload(MyLocalizationsDelegate old) => false;
}
