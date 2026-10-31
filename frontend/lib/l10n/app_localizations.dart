import 'package:flutter/material.dart';
import 'self_hosted_legal.dart';

class AppLocalizations {
  final Locale locale;

  const AppLocalizations(this.locale);

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('es'),
    Locale('de'),
    Locale('it'),
    Locale('ja'),
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('fr'));
  }

  String t(String key) {
    final languageCode = locale.languageCode;
    final legal = selfHostedLegal(key, languageCode);
    if (legal != null) return legal;
    final legacyKey =
        const {
          'Paramètres': 'Parametres',
          'Dépenses': 'Depenses',
          'Réinitialiser': 'Reinitialiser',
          'Sécurité et confidentialité': 'Securite et confidentialite',
          'Données personnelles': 'Donnees personnelles',
          'À propos': 'A propos',
          'Déconnexion': 'Deconnexion',
          'Prénom': 'Prenom',
          'Téléphone': 'Telephone',
          'Alertes budgétaires': 'Alertes budgetaires',
        }[key] ??
        key;
    final complement =
        _translationComplements[languageCode]?[key] ??
        _translationComplements[languageCode]?[legacyKey];
    if (complement != null) return complement;
    if (languageCode == 'fr') return key;
    return _translations[languageCode]?[key] ??
        _translations[languageCode]?[legacyKey] ??
        _translationComplements['fr']?[key] ??
        key;
  }

  String type(String value) {
    return t(_typeLabels[value] ?? value);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();
}

extension AppTranslate on BuildContext {
  String tr(String key) => AppLocalizations.of(this).t(key);
  String trType(String value) => AppLocalizations.of(this).type(value);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supported) => supported.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

const _typeLabels = {
  'expense': 'Depense',
  'income': 'Revenu',
  'investment': 'Investissement',
  'transfer': 'Transfert',
};

const Map<String, Map<String, String>> _translationComplements = {
  'fr': {
    'legal_terms_full': '''
Conditions générales d’utilisation de MySold
Version du 15 juillet 2026

1. Objet
MySold est une application de suivi budgétaire personnel. Elle permet de saisir, consulter et organiser des comptes, catégories, transactions, investissements, alertes budgétaires, statistiques et rapports d’export. L’application aide l’utilisateur à mieux visualiser ses finances personnelles, mais elle ne remplace pas une banque, un conseiller financier, un conseiller fiscal, un avocat ou un expert-comptable.

2. Acceptation des conditions
En créant un compte, en se connectant ou en utilisant MySold, l’utilisateur accepte les présentes conditions. Si l’utilisateur n’accepte pas ces conditions, il doit cesser d’utiliser l’application.

3. Compte utilisateur et sécurité
L’utilisateur est responsable de l’exactitude des informations saisies, de la confidentialité de ses identifiants et de son code PIN. Toute action réalisée depuis son compte est réputée réalisée par lui. En cas de suspicion d’accès non autorisé, l’utilisateur doit changer son mot de passe et supprimer les accès non souhaités.

4. Données saisies par l’utilisateur
L’utilisateur garantit que les données qu’il renseigne lui appartiennent ou qu’il dispose de l’autorisation nécessaire pour les utiliser. MySold ne vérifie pas l’exactitude des soldes, transactions, catégories ou investissements saisis.

5. Absence de conseil financier
Les informations, statistiques, projections, graphiques et rapports fournis par MySold sont indicatifs. Ils ne constituent pas un conseil financier, bancaire, fiscal, juridique ou d’investissement. L’utilisateur reste seul responsable de ses décisions, opérations bancaires, investissements, déclarations fiscales et choix patrimoniaux.

6. Export, import et suppression des données
MySold permet d’exporter les données utilisateur au format CSV et de générer des rapports PDF. L’utilisateur peut demander la suppression de son compte et de ses données depuis l’application. Cette suppression est irréversible. Il est fortement conseillé d’exporter ses données avant toute suppression. Lors d’un import, l’utilisateur doit vérifier les données restaurées et gérer les doublons proposés par l’application.

7. Disponibilité du service
MySold peut dépendre de services tiers, notamment Firebase et Google. L’application peut être interrompue temporairement pour maintenance, incident technique, évolution du service ou indisponibilité d’un prestataire. Aucune garantie de disponibilité permanente n’est donnée.

8. Usages interdits
Il est interdit d’utiliser MySold pour tenter d’accéder aux données d’autrui, contourner les protections de sécurité, perturber le service, importer des données illicites, usurper une identité ou utiliser l’application à des fins frauduleuses.

9. Propriété intellectuelle
L’application MySold, son nom, son interface, ses textes, sa logique applicative et ses éléments graphiques sont protégés. L’utilisateur conserve ses droits sur les données qu’il saisit, mais ne dispose d’aucun droit de copie, revente ou exploitation non autorisée de l’application.

10. Évolution des conditions
Les présentes conditions peuvent être modifiées pour tenir compte de l’évolution de l’application, de la loi ou des services utilisés. La version applicable est celle disponible dans l’application au moment de l’utilisation.

11. Contact
Pour toute question relative aux conditions d’utilisation, à la confidentialité ou aux données personnelles, l’utilisateur peut contacter l’éditeur de MySold à l’adresse de contact officielle qui sera indiquée dans l’application ou sur le site de présentation.
''',
    'privacy_policy_full': '''
Politique de confidentialité de MySold
Version du 15 juillet 2026

1. Objet
La présente politique explique quelles données sont traitées par MySold, pourquoi elles sont utilisées, où elles sont stockées et quels droits l’utilisateur peut exercer. Elle est rédigée dans un objectif de transparence conforme aux principes du RGPD : information claire, finalités déterminées, minimisation des données, sécurité et contrôle par l’utilisateur.

2. Données collectées
MySold peut traiter les données suivantes : informations de compte utilisateur, adresse e-mail, nom, prénom, téléphone si renseigné, préférences de langue, devise, thème, paramètres de sécurité, date de création, dernière connexion, comptes créés dans l’application, catégories, investissements, transactions, transferts, alertes budgétaires, exports et données nécessaires au fonctionnement de l’authentification.

3. Données financières
Les montants, comptes, transactions, investissements et catégories renseignés dans MySold sont des données sensibles de fait, car elles concernent la situation financière personnelle de l’utilisateur. MySold les utilise uniquement pour fournir les fonctionnalités de suivi, d’affichage, de statistiques, d’alertes, d’export, d’import et de suppression demandées par l’utilisateur.

4. Finalités du traitement
Les données sont utilisées pour créer et sécuriser le compte, synchroniser les données entre appareils, afficher les vues mensuelles et globales, calculer les statistiques, gérer les alertes budgétaires locales, générer des exports CSV/PDF, permettre l’import de données, appliquer les préférences utilisateur et assurer la sécurité du compte.

5. Base légale
Le traitement est fondé principalement sur l’exécution du service demandé par l’utilisateur, son consentement lors de la création du compte et l’intérêt légitime de sécuriser l’application, prévenir les abus et maintenir le service.

6. Stockage et prestataires
Les données sont stockées dans Firebase, notamment Firebase Authentication et Cloud Firestore. L’authentification Google peut être utilisée si l’utilisateur choisit de se connecter avec Google. Ces services sont fournis par Google/Firebase et peuvent impliquer des traitements techniques nécessaires à l’hébergement, la sécurité et la synchronisation.

7. Partage des données
MySold ne vend pas les données personnelles de l’utilisateur. Les données ne sont pas transmises à des tiers commerciaux. Elles peuvent être traitées par les prestataires techniques indispensables au fonctionnement du service ou communiquées si une obligation légale l’impose.

8. Sécurité
MySold met en place plusieurs mesures de sécurité : authentification Firebase, code PIN local pour les actions sensibles, demande de PIN avant export/import/suppression, mode discret pour masquer les montants, règles Firestore limitées à l’utilisateur connecté et export volontaire par l’utilisateur. Aucune mesure de sécurité n’étant absolue, l’utilisateur doit aussi protéger son appareil, son mot de passe et son compte Google ou e-mail.

9. Conservation
Les données sont conservées tant que le compte utilisateur existe ou tant qu’elles sont nécessaires au fonctionnement du service. La date de dernière connexion peut être utilisée pour détecter l’inactivité. À terme, MySold pourra supprimer les comptes et données après une longue période d’inactivité, par exemple trois ans, après information préalable lorsque cela est techniquement possible.

10. Export et portabilité
L’utilisateur peut exporter ses données depuis l’application au format CSV. Ce fichier contient une structure permettant de comprendre les collections, documents, champs et chemins Firestore afin de faciliter une réimportation ou une portabilité.

11. Suppression
L’utilisateur peut demander la suppression de son compte et de ses données depuis la page Sécurité et confidentialité. Cette action supprime les données connues de l’espace utilisateur et le compte d’authentification lorsque Firebase l’autorise. L’action est irréversible. Un export préalable est fortement conseillé.

12. Droits de l’utilisateur
Conformément aux principes du RGPD, l’utilisateur peut demander l’accès à ses données, leur rectification, leur export, leur suppression, la limitation de certains traitements ou s’opposer à certains traitements lorsque cela est applicable. Plusieurs droits peuvent déjà être exercés directement dans l’application via les fonctions d’export, modification et suppression.

13. Mineurs
MySold est destinée à un usage personnel par des utilisateurs capables de gérer leurs données financières. Les mineurs ne doivent utiliser l’application qu’avec l’accord de leur représentant légal.

14. Modifications
Cette politique peut évoluer pour suivre les modifications de l’application, des prestataires ou des obligations légales. La version applicable est celle affichée dans l’application.

15. Contact
Pour toute demande concernant les données personnelles, l’utilisateur peut contacter l’éditeur de MySold à l’adresse officielle qui sera indiquée dans l’application ou sur le site de présentation.
''',
  },
  'es': {
    'Rechercher une catégorie': 'Buscar una categoría',
    'Nom : A → Z': 'Nombre: A → Z',
    'Nom : Z → A': 'Nombre: Z → A',
    'Montant croissant': 'Importe ascendente',
    'Montant décroissant': 'Importe descendente',
    'Filtrer par montant': 'Filtrar por importe',
    'Montant filtré': 'Importe filtrado',
    'Montant cumulé des transactions de chaque catégorie.':
        'Importe acumulado de las transacciones de cada categoría.',
    'Saisissez un montant positif ou nul.':
        'Introduce un importe mayor o igual a cero.',
    'Le maximum doit être supérieur ou égal au minimum.':
        'El máximo debe ser mayor o igual al mínimo.',
    'Aucune catégorie ne correspond aux filtres.':
        'Ninguna categoría coincide con los filtros.',
    'Choisir un mois': 'Elegir un mes',
    'Année': 'Año',
    'Année précédente': 'Año anterior',
    'Année suivante': 'Año siguiente',
    'Saisissez une année entre 1 et 9999.': 'Introduce un año entre 1 y 9999.',
    'Réinitialiser': 'Restablecer',
    'Évolution mensuelle': 'Evolución mensual',
    'Touchez ou survolez un mois pour voir les montants.':
        'Toca un mes o pasa el cursor para ver los importes.',
    'Actif': 'Activo',
    'Adresse email invalide.': 'Dirección de email inválida.',
    'Afficher': 'Mostrar',
    'Ajouter une operation': 'Añadir una operación',
    'Ajoutez une categorie pour organiser vos transactions.':
        'Añade una categoría para organizar tus transacciones.',
    'Ajuster l actif': 'Ajustar el activo',
    'Ajuster la categorie': 'Ajustar la categoría',
    'Ajuster le compte': 'Ajustar la cuenta',
    'Alerte active': 'Alerta activa',
    'Alerte desactivee': 'Alerta desactivada',
    'Alertes du mois': 'Alertas del mes',
    'Annee complete': 'Año completo',
    'Application en developpement actif.': 'Aplicación en desarrollo activo.',
    'Apres 1 heure': 'Después de 1 hora',
    'Apres 1 minute': 'Después de 1 minuto',
    'Apres 15 minutes': 'Después de 15 minutos',
    'Apres 5 minutes': 'Después de 5 minutos',
    'Aucun compte disponible.': 'No hay cuenta disponible.',
    'Aucun compte ou investissement disponible.':
        'No hay cuenta o inversión disponible.',
    'Aucun resultat pour :': 'Sin resultados para:',
    'Aucun revenu recurrent detecte pour le moment.':
        'No se detectaron ingresos recurrentes por ahora.',
    'Aucune depense ce mois-ci.': 'No hay gastos este mes.',
    'Aucune depense pour cette annee.': 'No hay gastos este año.',
    'Aucune limite': 'Sin límite',
    'Aucune nouvelle alerte declenchee': 'No se activó ninguna alerta nueva',
    'Aucune transaction a exporter.': 'No hay transacción para exportar.',
    'Aucune transaction ne correspond aux filtres.':
        'Ninguna transacción coincide con los filtros.',
    'Aucune transaction sur cette periode.':
        'No hay transacciones en este período.',
    'Autoriser MySold a prevenir sur ce telephone':
        'Permitir que MySold avise en este teléfono',
    'Autre': 'Otro',
    'Balance annuelle': 'Balance anual',
    'Basee sur le rythme quotidien du mois en cours.':
        'Basada en el ritmo diario del mes actual.',
    'Categorie enregistree': 'Categoría guardada',
    'Ce compte est utilise par des transactions ou investissements.':
        'Esta cuenta se usa en transacciones o inversiones.',
    'Ce mois-ci': 'Este mes',
    'Cet investissement est utilise ou possede encore un solde.':
        'Esta inversión se usa o todavía tiene saldo.',
    'Cette categorie est utilisee par des transactions.':
        'Esta categoría se usa en transacciones.',
    'Cette limite budgetaire sera supprimee.':
        'Este límite presupuestario se eliminará.',
    'Changer la date': 'Cambiar la fecha',
    'Chargement des references...': 'Cargando referencias...',
    'Chargement des transactions...': 'Cargando transacciones...',
    'Choisir un compte': 'Elegir una cuenta',
    'Choisir un compte destination': 'Elegir una cuenta destino',
    'Choisir un compte different': 'Elegir una cuenta diferente',
    'Choisir un compte source': 'Elegir una cuenta origen',
    'Choisir une couleur': 'Elegir un color',
    'Choisir une icone': 'Elegir un icono',
    'Compte de detention': 'Cuenta de custodia',
    'Compte destination': 'Cuenta destino',
    'Compte enregistre': 'Cuenta guardada',
    'Compte inconnu': 'Cuenta desconocida',
    'Compte investissement': 'Cuenta de inversión',
    'Compte investissement auto': 'Cuenta de inversión automática',
    'Compte gere par les investissements': 'Cuenta gestionada por inversiones',
    'Compte qui recoit l investissement': 'Cuenta que recibe la inversión',
    'Compte source': 'Cuenta origen',
    'Compte support': 'Cuenta soporte',
    'Confirmer le mot de passe': 'Confirmar la contraseña',
    'Confirmer le PIN': 'Confirmar el PIN',
    'Confirmez votre PIN avant de supprimer ce compte.':
        'Confirma tu PIN antes de eliminar esta cuenta.',
    'Confirmez votre PIN avant de supprimer cette categorie.':
        'Confirma tu PIN antes de eliminar esta categoría.',
    'Connectez-vous a votre espace bancaire.':
        'Conéctate a tu espacio bancario.',
    'Connexion Google annulee ou impossible':
        'Conexión con Google cancelada o imposible',
    'Connexion Google...': 'Conectando con Google...',
    'Connexion...': 'Conectando...',
    'Contenu du rapport': 'Contenido del informe',
    'Continuer avec Google': 'Continuar con Google',
    'Couleur personnalisee': 'Color personalizado',
    'Creation du compte': 'Creación de cuenta',
    'Creer mon compte': 'Crear mi cuenta',
    'Creer mon PIN': 'Crear mi PIN',
    'Creer un actif': 'Crear un activo',
    'Creer une categorie': 'Crear una categoría',
    'Creer votre PIN': 'Crear tu PIN',
    'Delai avant verrouillage': 'Tiempo antes del bloqueo',
    'Demande de reconnexion tous les...': 'Solicitar reconexión cada...',
    'Demande du PIN': 'Solicitud de PIN',
    'Depenses mensuelles': 'Gastos mensuales',
    'Destination (action, fonds...)': 'Destino (acción, fondo...)',
    'Deverrouiller': 'Desbloquear',
    'Donnees personnelles enregistrees': 'Datos personales guardados',
    'Elle apparaitra dans les depenses.': 'Aparecerá en los gastos.',
    'Elle apparaitra dans les revenus.': 'Aparecerá en los ingresos.',
    'Email de reinitialisation envoye': 'Email de restablecimiento enviado',
    'En surveillance': 'En seguimiento',
    'Enregistrement du fichier...': 'Guardando archivo...',
    'Entrer un montant': 'Introducir un importe',
    'Entrez un nom d investissement': 'Introduce un nombre de inversión',
    'Entrez un nom de categorie': 'Introduce un nombre de categoría',
    'Entrez un nom de compte': 'Introduce un nombre de cuenta',
    'Entrez un solde': 'Introduce un saldo',
    'Erreur de connexion': 'Error de conexión',
    'Erreur lors de la creation du compte': 'Error al crear la cuenta',
    'Export impossible': 'Exportación imposible',
    'Exporter un rapport': 'Exportar un informe',
    'Fichier enregistre.': 'Archivo guardado.',
    'Generation du PDF...': 'Generando PDF...',
    'Generation du rapport': 'Generación del informe',
    'Generer le PDF': 'Generar el PDF',
    'Gestion des categories': 'Gestión de categorías',
    'Gestion des comptes': 'Gestión de cuentas',
    'Gestion des investissements': 'Gestión de inversiones',
    'Informations du compte': 'Información de la cuenta',
    'Informations personnelles': 'Información personal',
    'Investissement enregistre': 'Inversión guardada',
    'La categorie Others est protegee': 'La categoría Others está protegida',
    'Le montant doit etre superieur a 0.': 'El importe debe ser superior a 0.',
    'Le PIN doit faire 6 chiffres identiques':
        'El PIN debe tener 6 cifras idénticas',
    'Le rapport sera genere en arriere-plan.':
        'El informe se generará en segundo plano.',
    'Le solde de ce compte sera calcule depuis les actifs.':
        'El saldo de esta cuenta se calculará desde los activos.',
    'Les comptes doivent etre differents': 'Las cuentas deben ser diferentes',
    'Les mots de passe ne correspondent pas.': 'Las contraseñas no coinciden.',
    'Masquer les montants': 'Ocultar importes',
    'Mettre a jour': 'Actualizar',
    'Mode discret actif dans les parametres': 'Modo discreto activo en ajustes',
    'Modifier l alerte': 'Modificar la alerta',
    'Modifier l investissement': 'Modificar la inversión',
    'Modifier la categorie': 'Modificar la categoría',
    'Modifier la transaction': 'Modificar la transacción',
    'Modifier le compte': 'Modificar la cuenta',
    'Modifier le transfert': 'Modificar la transferencia',
    'mois detectes': 'meses detectados',
    'Montant invalide': 'Importe inválido',
    'Montants masques': 'Importes ocultos',
    'Montants visibles': 'Importes visibles',
    'Mot de passe oublie ?': '¿Contraseña olvidada?',
    'Nom de l alerte': 'Nombre de la alerta',
    'Nom de l investissement': 'Nombre de la inversión',
    'Nom de la categorie': 'Nombre de la categoría',
    'Nom du compte': 'Nombre de la cuenta',
    'Notifications locales': 'Notificaciones locales',
    'Nouveau compte': 'Nueva cuenta',
    'Nouveau PIN': 'Nuevo PIN',
    'Nouveau transfert': 'Nueva transferencia',
    'Nouvel investissement': 'Nueva inversión',
    'Nouvelle alerte': 'Nueva alerta',
    'Nouvelle categorie': 'Nueva categoría',
    'Nouvelle transaction': 'Nueva transacción',
    'Ordre croissant': 'Orden ascendente',
    'Ordre decroissant': 'Orden descendente',
    'Parametres de securite enregistres': 'Ajustes de seguridad guardados',
    'Periode personnalisee': 'Período personalizado',
    'PIN (6 chiffres)': 'PIN (6 cifras)',
    'PIN incorrect': 'PIN incorrecto',
    'Preferences utilisateur': 'Preferencias de usuario',
    'Preparation des donnees...': 'Preparando datos...',
    'Projection': 'Proyección',
    'Rappel mensuel': 'Recordatorio mensual',
    'Rechercher une icone': 'Buscar un icono',
    'Rechercher une transaction': 'Buscar una transacción',
    'Recherche': 'Búsqueda',
    'Reel': 'Real',
    'Remplace les montants visibles par des symboles':
        'Reemplaza los importes visibles por símbolos',
    'Retour': 'Volver',
    'Sans nom': 'Sin nombre',
    'Se souvenir de moi': 'Recordarme',
    'Securite de l application': 'Seguridad de la aplicación',
    'Selectionner un compte': 'Seleccionar una cuenta',
    'Selectionnez deux comptes valides.': 'Selecciona dos cuentas válidas.',
    'Selectionnez un compte et une categorie valides.':
        'Selecciona una cuenta y una categoría válidas.',
    'Selectionnez votre devise': 'Selecciona tu moneda',
    'Selectionnez votre langue': 'Selecciona tu idioma',
    'Selectionnez votre theme': 'Selecciona tu tema',
    'Seuil atteint': 'Umbral alcanzado',
    'Seuils depenses / revenus du mois': 'Umbrales gastos / ingresos del mes',
    'Solde actuel': 'Saldo actual',
    'Solde initial': 'Saldo inicial',
    'Solde invalide': 'Saldo inválido',
    'Solde total des comptes': 'Saldo total de las cuentas',
    'Suivant': 'Siguiente',
    'Suppression protegee': 'Eliminación protegida',
    'Supprimer cette operation investissement ?':
        '¿Eliminar esta operación de inversión?',
    'Supprimer l alerte': 'Eliminar la alerta',
    'Supprimer l investissement': 'Eliminar la inversión',
    'Supprimer la categorie': 'Eliminar la categoría',
    'Supprimer le compte': 'Eliminar la cuenta',
    'Telechargement lance.': 'Descarga iniciada.',
    'Toutes les categories': 'Todas las categorías',
    'Tous les comptes': 'Todas las cuentas',
    'Transactions mensuelles': 'Transacciones mensuales',
    'Trier par': 'Ordenar por',
    'Verification...': 'Verificación...',
    'Veuillez entrer un email valide': 'Introduce un email válido',
    'Veuillez selectionner les comptes et un investissement.':
        'Selecciona las cuentas y una inversión.',
    'Voulez-vous vraiment supprimer ce transfert ?':
        '¿Seguro que quieres eliminar esta transferencia?',
    'Voulez-vous vraiment supprimer cette transaction ?':
        '¿Seguro que quieres eliminar esta transacción?',
  },
  'de': {
    'Rechercher une catégorie': 'Kategorie suchen',
    'Nom : A → Z': 'Name: A → Z',
    'Nom : Z → A': 'Name: Z → A',
    'Montant croissant': 'Betrag aufsteigend',
    'Montant décroissant': 'Betrag absteigend',
    'Filtrer par montant': 'Nach Betrag filtern',
    'Montant filtré': 'Betrag gefiltert',
    'Montant cumulé des transactions de chaque catégorie.':
        'Gesamtbetrag der Transaktionen jeder Kategorie.',
    'Saisissez un montant positif ou nul.':
        'Gib einen Betrag größer oder gleich null ein.',
    'Le maximum doit être supérieur ou égal au minimum.':
        'Das Maximum muss mindestens dem Minimum entsprechen.',
    'Aucune catégorie ne correspond aux filtres.':
        'Keine Kategorie entspricht den Filtern.',
    'Choisir un mois': 'Monat auswählen',
    'Année': 'Jahr',
    'Année précédente': 'Vorheriges Jahr',
    'Année suivante': 'Nächstes Jahr',
    'Saisissez une année entre 1 et 9999.':
        'Gib ein Jahr zwischen 1 und 9999 ein.',
    'Réinitialiser': 'Zurücksetzen',
    'Évolution mensuelle': 'Monatliche Entwicklung',
    'Touchez ou survolez un mois pour voir les montants.':
        'Tippe auf einen Monat oder bewege den Zeiger darüber, um die Beträge zu sehen.',
    'Actif': 'Anlage',
    'Ajouter': 'Hinzufügen',
    'Ajouter un actif': 'Anlage hinzufügen',
    'Ajouter un compte': 'Konto hinzufügen',
    'Ajouter une alerte': 'Alarm hinzufügen',
    'Ajouter une categorie': 'Kategorie hinzufügen',
    'Alerte': 'Alarm',
    'Alertes budgetaires': 'Budgetalarme',
    'Annuler': 'Abbrechen',
    'Appliquer': 'Anwenden',
    'Aucun actif': 'Keine Anlage',
    'Aucun compte': 'Kein Konto',
    'Afficher': 'Anzeigen',
    'Ajouter une operation': 'Vorgang hinzufügen',
    'Alerte active': 'Alarm aktiv',
    'Alerte desactivee': 'Alarm deaktiviert',
    'Annee complete': 'Ganzes Jahr',
    'Apres 1 heure': 'Nach 1 Stunde',
    'Apres 1 minute': 'Nach 1 Minute',
    'Apres 15 minutes': 'Nach 15 Minuten',
    'Apres 5 minutes': 'Nach 5 Minuten',
    'Aucun resultat pour :': 'Kein Ergebnis für:',
    'Autre': 'Andere',
    'Ce mois-ci': 'Diesen Monat',
    'Changer la date': 'Datum ändern',
    'Chargement des references...': 'Referenzen werden geladen...',
    'Chargement des transactions...': 'Transaktionen werden geladen...',
    'Choisir un compte': 'Konto wählen',
    'Choisir une couleur': 'Farbe wählen',
    'Choisir une icone': 'Symbol wählen',
    'Categorie': 'Kategorie',
    'Categories': 'Kategorien',
    'Compte': 'Konto',
    'Comptes': 'Konten',
    'Compte destination': 'Zielkonto',
    'Compte source': 'Quellkonto',
    'Confirmer le mot de passe': 'Passwort bestätigen',
    'Contenu du rapport': 'Berichtsinhalt',
    'Couleur personnalisee': 'Eigene Farbe',
    'Creation du compte': 'Kontoerstellung',
    'Creer mon compte': 'Mein Konto erstellen',
    'Creer une categorie': 'Kategorie erstellen',
    'Demande du PIN': 'PIN-Abfrage',
    'Depenses mensuelles': 'Monatliche Ausgaben',
    'Depense': 'Ausgabe',
    'Depenses': 'Ausgaben',
    'Description': 'Beschreibung',
    'Enregistrement du fichier...': 'Datei wird gespeichert...',
    'Entrer un montant': 'Betrag eingeben',
    'Export impossible': 'Export nicht möglich',
    'Exporter un rapport': 'Bericht exportieren',
    'Fichier enregistre.': 'Datei gespeichert.',
    'Generation du PDF...': 'PDF wird erstellt...',
    'Generation du rapport': 'Berichtserstellung',
    'Generer le PDF': 'PDF erstellen',
    'Icone': 'Symbol',
    'Informations du compte': 'Kontoinformationen',
    'Informations personnelles': 'Persönliche Informationen',
    'Investissement': 'Investition',
    'Investissements': 'Investitionen',
    'Le montant doit etre superieur a 0.': 'Der Betrag muss größer als 0 sein.',
    'Les comptes doivent etre differents':
        'Die Konten müssen unterschiedlich sein',
    'Masquer les montants': 'Beträge ausblenden',
    'Mettre a jour': 'Aktualisieren',
    'Modifier la transaction': 'Transaktion bearbeiten',
    'Montant': 'Betrag',
    'Montant max': 'Maximalbetrag',
    'Montant min': 'Mindestbetrag',
    'Mot de passe': 'Passwort',
    'Nom': 'Nachname',
    'Parametres': 'Einstellungen',
    'Periode': 'Zeitraum',
    'Prenom': 'Vorname',
    'Nouveau transfert': 'Neue Überweisung',
    'Nouvelle transaction': 'Neue Transaktion',
    'Ordre croissant': 'Aufsteigend',
    'Ordre decroissant': 'Absteigend',
    'Periode personnalisee': 'Benutzerdefinierter Zeitraum',
    'PIN incorrect': 'Falsche PIN',
    'Preparation des donnees...': 'Daten werden vorbereitet...',
    'Rechercher une icone': 'Symbol suchen',
    'Rechercher une transaction': 'Transaktion suchen',
    'Recherche': 'Suche',
    'Retour': 'Zurück',
    'Revenu': 'Einnahme',
    'Revenus': 'Einnahmen',
    'Selectionner un compte': 'Konto auswählen',
    'Selectionnez votre devise': 'Währung auswählen',
    'Selectionnez votre langue': 'Sprache auswählen',
    'Selectionnez votre theme': 'Design auswählen',
    'Suivant': 'Weiter',
    'Supprimer': 'Löschen',
    'Telechargement lance.': 'Download gestartet.',
    'Telephone': 'Telefon',
    'Theme': 'Design',
    'Toutes les categories': 'Alle Kategorien',
    'Tous les comptes': 'Alle Konten',
    'Transactions mensuelles': 'Monatliche Transaktionen',
    'Transfert': 'Überweisung',
    'Transferts': 'Überweisungen',
    'Type': 'Typ',
    'Verification...': 'Prüfung...',
  },
  'it': {
    'Rechercher une catégorie': 'Cerca una categoria',
    'Nom : A → Z': 'Nome: A → Z',
    'Nom : Z → A': 'Nome: Z → A',
    'Montant croissant': 'Importo crescente',
    'Montant décroissant': 'Importo decrescente',
    'Filtrer par montant': 'Filtra per importo',
    'Montant filtré': 'Importo filtrato',
    'Montant cumulé des transactions de chaque catégorie.':
        'Importo totale delle transazioni di ogni categoria.',
    'Saisissez un montant positif ou nul.':
        'Inserisci un importo maggiore o uguale a zero.',
    'Le maximum doit être supérieur ou égal au minimum.':
        'Il massimo deve essere maggiore o uguale al minimo.',
    'Aucune catégorie ne correspond aux filtres.':
        'Nessuna categoria corrisponde ai filtri.',
    'Choisir un mois': 'Scegli un mese',
    'Année': 'Anno',
    'Année précédente': 'Anno precedente',
    'Année suivante': 'Anno successivo',
    'Saisissez une année entre 1 et 9999.':
        'Inserisci un anno compreso tra 1 e 9999.',
    'Réinitialiser': 'Reimposta',
    'Évolution mensuelle': 'Andamento mensile',
    'Touchez ou survolez un mois pour voir les montants.':
        'Tocca un mese o passa il puntatore per vedere gli importi.',
    'Actif': 'Asset',
    'Ajouter': 'Aggiungi',
    'Ajouter un actif': 'Aggiungi asset',
    'Ajouter un compte': 'Aggiungi conto',
    'Ajouter une alerte': 'Aggiungi avviso',
    'Ajouter une categorie': 'Aggiungi categoria',
    'Alerte': 'Avviso',
    'Alertes budgetaires': 'Avvisi budget',
    'Annuler': 'Annulla',
    'Appliquer': 'Applica',
    'Aucun actif': 'Nessun asset',
    'Aucun compte': 'Nessun conto',
    'Afficher': 'Mostra',
    'Ajouter une operation': 'Aggiungi operazione',
    'Alerte active': 'Avviso attivo',
    'Alerte desactivee': 'Avviso disattivato',
    'Annee complete': 'Anno completo',
    'Apres 1 heure': 'Dopo 1 ora',
    'Apres 1 minute': 'Dopo 1 minuto',
    'Apres 15 minutes': 'Dopo 15 minuti',
    'Apres 5 minutes': 'Dopo 5 minuti',
    'Aucun resultat pour :': 'Nessun risultato per:',
    'Autre': 'Altro',
    'Ce mois-ci': 'Questo mese',
    'Changer la date': 'Cambia data',
    'Chargement des references...': 'Caricamento riferimenti...',
    'Chargement des transactions...': 'Caricamento transazioni...',
    'Choisir un compte': 'Scegli un conto',
    'Choisir une couleur': 'Scegli un colore',
    'Choisir une icone': 'Scegli un icona',
    'Categorie': 'Categoria',
    'Categories': 'Categorie',
    'Compte': 'Conto',
    'Comptes': 'Conti',
    'Compte destination': 'Conto destinazione',
    'Compte source': 'Conto origine',
    'Confirmer le mot de passe': 'Conferma password',
    'Contenu du rapport': 'Contenuto del report',
    'Couleur personnalisee': 'Colore personalizzato',
    'Creation du compte': 'Creazione account',
    'Creer mon compte': 'Crea il mio account',
    'Creer une categorie': 'Crea categoria',
    'Demande du PIN': 'Richiesta PIN',
    'Depenses mensuelles': 'Spese mensili',
    'Depense': 'Spesa',
    'Depenses': 'Spese',
    'Description': 'Descrizione',
    'Enregistrement du fichier...': 'Salvataggio file...',
    'Entrer un montant': 'Inserisci un importo',
    'Export impossible': 'Export impossibile',
    'Exporter un rapport': 'Esporta un report',
    'Fichier enregistre.': 'File salvato.',
    'Generation du PDF...': 'Generazione PDF...',
    'Generation du rapport': 'Generazione report',
    'Generer le PDF': 'Genera PDF',
    'Icone': 'Icona',
    'Informations du compte': 'Informazioni account',
    'Informations personnelles': 'Informazioni personali',
    'Investissement': 'Investimento',
    'Investissements': 'Investimenti',
    'Le montant doit etre superieur a 0.':
        'L importo deve essere superiore a 0.',
    'Les comptes doivent etre differents': 'I conti devono essere diversi',
    'Masquer les montants': 'Nascondi importi',
    'Mettre a jour': 'Aggiorna',
    'Modifier la transaction': 'Modifica transazione',
    'Montant': 'Importo',
    'Montant max': 'Importo massimo',
    'Montant min': 'Importo minimo',
    'Mot de passe': 'Password',
    'Nom': 'Cognome',
    'Parametres': 'Impostazioni',
    'Periode': 'Periodo',
    'Prenom': 'Nome',
    'Nouveau transfert': 'Nuovo trasferimento',
    'Nouvelle transaction': 'Nuova transazione',
    'Ordre croissant': 'Ordine crescente',
    'Ordre decroissant': 'Ordine decrescente',
    'Periode personnalisee': 'Periodo personalizzato',
    'PIN incorrect': 'PIN errato',
    'Preparation des donnees...': 'Preparazione dati...',
    'Rechercher une icone': 'Cerca icona',
    'Rechercher une transaction': 'Cerca transazione',
    'Recherche': 'Ricerca',
    'Retour': 'Indietro',
    'Revenu': 'Entrata',
    'Revenus': 'Entrate',
    'Selectionner un compte': 'Seleziona un conto',
    'Selectionnez votre devise': 'Seleziona valuta',
    'Selectionnez votre langue': 'Seleziona lingua',
    'Selectionnez votre theme': 'Seleziona tema',
    'Suivant': 'Avanti',
    'Supprimer': 'Elimina',
    'Telechargement lance.': 'Download avviato.',
    'Telephone': 'Telefono',
    'Theme': 'Tema',
    'Toutes les categories': 'Tutte le categorie',
    'Tous les comptes': 'Tutti i conti',
    'Transactions mensuelles': 'Transazioni mensili',
    'Transfert': 'Trasferimento',
    'Transferts': 'Trasferimenti',
    'Type': 'Tipo',
    'Verification...': 'Verifica...',
  },
  'ja': {
    'Rechercher une catégorie': 'カテゴリを検索',
    'Nom : A → Z': '名前：昇順',
    'Nom : Z → A': '名前：降順',
    'Montant croissant': '金額の昇順',
    'Montant décroissant': '金額の降順',
    'Filtrer par montant': '金額で絞り込む',
    'Montant filtré': '金額の絞り込み中',
    'Montant cumulé des transactions de chaque catégorie.': '各カテゴリの取引の合計金額。',
    'Saisissez un montant positif ou nul.': '0以上の金額を入力してください。',
    'Le maximum doit être supérieur ou égal au minimum.': '最大金額は最小金額以上にしてください。',
    'Aucune catégorie ne correspond aux filtres.': '条件に一致するカテゴリはありません。',
    'Choisir un mois': '月を選択',
    'Année': '年',
    'Année précédente': '前年',
    'Année suivante': '翌年',
    'Saisissez une année entre 1 et 9999.': '1から9999の年を入力してください。',
    'Réinitialiser': 'リセット',
    'Évolution mensuelle': '月ごとの推移',
    'Touchez ou survolez un mois pour voir les montants.':
        '月をタップするか、カーソルを合わせると金額を確認できます。',
    'Actif': '資産',
    'Ajouter': '追加',
    'Ajouter un actif': '資産を追加',
    'Ajouter un compte': '口座を追加',
    'Ajouter une alerte': 'アラートを追加',
    'Ajouter une categorie': 'カテゴリを追加',
    'Alerte': 'アラート',
    'Alertes budgetaires': '予算アラート',
    'Annuler': 'キャンセル',
    'Appliquer': '適用',
    'Aucun actif': '資産なし',
    'Aucun compte': '口座なし',
    'Afficher': '表示',
    'Ajouter une operation': '操作を追加',
    'Alerte active': 'アラート有効',
    'Alerte desactivee': 'アラート無効',
    'Annee complete': '年間全体',
    'Apres 1 heure': '1時間後',
    'Apres 1 minute': '1分後',
    'Apres 15 minutes': '15分後',
    'Apres 5 minutes': '5分後',
    'Aucun resultat pour :': '結果なし:',
    'Autre': 'その他',
    'Ce mois-ci': '今月',
    'Changer la date': '日付を変更',
    'Chargement des references...': '参照データを読み込み中...',
    'Chargement des transactions...': '取引を読み込み中...',
    'Choisir un compte': '口座を選択',
    'Choisir une couleur': '色を選択',
    'Choisir une icone': 'アイコンを選択',
    'Categorie': 'カテゴリ',
    'Categories': 'カテゴリ',
    'Compte': '口座',
    'Comptes': '口座',
    'Compte destination': '移動先口座',
    'Compte source': '移動元口座',
    'Confirmer le mot de passe': 'パスワード確認',
    'Contenu du rapport': 'レポート内容',
    'Couleur personnalisee': 'カスタム色',
    'Creation du compte': 'アカウント作成',
    'Creer mon compte': 'アカウントを作成',
    'Creer une categorie': 'カテゴリ作成',
    'Demande du PIN': 'PIN要求',
    'Depenses mensuelles': '月間支出',
    'Depense': '支出',
    'Depenses': '支出',
    'Description': '説明',
    'Enregistrement du fichier...': 'ファイル保存中...',
    'Entrer un montant': '金額を入力',
    'Export impossible': 'エクスポートできません',
    'Exporter un rapport': 'レポートを出力',
    'Fichier enregistre.': 'ファイルを保存しました。',
    'Generation du PDF...': 'PDF生成中...',
    'Generation du rapport': 'レポート生成',
    'Generer le PDF': 'PDFを生成',
    'Icone': 'アイコン',
    'Informations du compte': 'アカウント情報',
    'Informations personnelles': '個人情報',
    'Investissement': '投資',
    'Investissements': '投資',
    'Le montant doit etre superieur a 0.': '金額は0より大きくしてください。',
    'Les comptes doivent etre differents': '口座は異なる必要があります',
    'Masquer les montants': '金額を非表示',
    'Mettre a jour': '更新',
    'Modifier la transaction': '取引を編集',
    'Montant': '金額',
    'Montant max': '最大金額',
    'Montant min': '最小金額',
    'Mot de passe': 'パスワード',
    'Nom': '姓',
    'Parametres': '設定',
    'Periode': '期間',
    'Prenom': '名',
    'Nouveau transfert': '新規振替',
    'Nouvelle transaction': '新規取引',
    'Ordre croissant': '昇順',
    'Ordre decroissant': '降順',
    'Periode personnalisee': 'カスタム期間',
    'PIN incorrect': 'PINが違います',
    'Preparation des donnees...': 'データ準備中...',
    'Rechercher une icone': 'アイコン検索',
    'Rechercher une transaction': '取引検索',
    'Recherche': '検索',
    'Retour': '戻る',
    'Revenu': '収入',
    'Revenus': '収入',
    'Selectionner un compte': '口座を選択',
    'Selectionnez votre devise': '通貨を選択',
    'Selectionnez votre langue': '言語を選択',
    'Selectionnez votre theme': 'テーマを選択',
    'Suivant': '次へ',
    'Supprimer': '削除',
    'Telechargement lance.': 'ダウンロードを開始しました。',
    'Telephone': '電話',
    'Theme': 'テーマ',
    'Toutes les categories': 'すべてのカテゴリ',
    'Tous les comptes': 'すべての口座',
    'Transactions mensuelles': '月間取引',
    'Transfert': '振替',
    'Transferts': '振替',
    'Type': '種類',
    'Verification...': '確認中...',
  },
};

const Map<String, Map<String, String>> _translations = {
  'en': {
    'Rechercher une catégorie': 'Search categories',
    'Nom : A → Z': 'Name: A → Z',
    'Nom : Z → A': 'Name: Z → A',
    'Montant croissant': 'Amount ascending',
    'Montant décroissant': 'Amount descending',
    'Filtrer par montant': 'Filter by amount',
    'Montant filtré': 'Amount filtered',
    'Montant cumulé des transactions de chaque catégorie.':
        'Total transaction amount for each category.',
    'Saisissez un montant positif ou nul.':
        'Enter an amount greater than or equal to zero.',
    'Le maximum doit être supérieur ou égal au minimum.':
        'The maximum must be greater than or equal to the minimum.',
    'Aucune catégorie ne correspond aux filtres.':
        'No categories match the filters.',
    'Choisir un mois': 'Choose a month',
    'Année': 'Year',
    'Année précédente': 'Previous year',
    'Année suivante': 'Next year',
    'Saisissez une année entre 1 et 9999.': 'Enter a year between 1 and 9999.',
    'Évolution mensuelle': 'Monthly trends',
    'Touchez ou survolez un mois pour voir les montants.':
        'Tap or hover over a month to see the amounts.',
    'Préférences rapides': 'Quick preferences',
    'Préférences avancées': 'Advanced preferences',
    'Notifications et mode discret': 'Notifications and privacy mode',
    'PIN, verrouillage et double authentification':
        'PIN, screen lock and two-factor authentication',
    'Nom, prénom et téléphone': 'First name, last name and phone number',
    'Sécurité de l’application': 'Application security',
    'Authentificateur TOTP': 'TOTP authenticator',
    'Configurer l’authentificateur et les codes de secours.':
        'Set up the authenticator and recovery codes.',
    'Version et informations de l’application':
        'Application version and information',
    'Autoriser MySold à afficher des notifications sur cet appareil.':
        'Allow MySold to show notifications on this device.',
    'Recevoir les alertes de seuils de votre budget mensuel.':
        'Receive threshold alerts for your monthly budget.',
    'Mois': 'Month',
    'Global': 'Global',
    'Stats': 'Stats',
    'Profil': 'Profile',
    'Parametres': 'Settings',
    'Theme': 'Theme',
    'Langue': 'Language',
    'Devise': 'Currency',
    'Securite': 'Security',
    'Securite et confidentialite': 'Security and privacy',
    'Donnees personnelles': 'Personal data',
    'Notifications': 'Notifications',
    'A propos': 'About',
    'Preferences': 'Preferences',
    'Prenom': 'First name',
    'Nom': 'Last name',
    'Telephone': 'Phone',
    'Donnees personnelles enregistrees': 'Personal data saved',
    'Confirmez votre PIN avant de modifier vos informations.':
        'Confirm your PIN before editing your information.',
    'Confirmez votre PIN avant de modifier la securite.':
        'Confirm your PIN before editing security.',
    'Demande du PIN': 'PIN request',
    'Delai avant verrouillage': 'Lock delay',
    'Apres 1 minute': 'After 1 minute',
    'Apres 5 minutes': 'After 5 minutes',
    'Apres 15 minutes': 'After 15 minutes',
    'Apres 1 heure': 'After 1 hour',
    'Remplace les montants visibles par des symboles':
        'Replaces visible amounts with symbols',
    'Nouveau PIN': 'New PIN',
    'Confirmer le PIN': 'Confirm PIN',
    'Le PIN doit faire 6 chiffres.': 'The PIN must be 6 digits.',
    'Le PIN doit faire 6 chiffres identiques':
        'The PIN must be 6 matching digits',
    'Parametres de securite enregistres': 'Security settings saved',
    'Notifications locales': 'Local notifications',
    'Autoriser MySold a prevenir sur ce telephone':
        'Allow MySold to alert on this phone',
    'Alertes budgetaires': 'Budget alerts',
    'Seuils depenses / revenus du mois': 'Monthly expense / income thresholds',
    'Rappel mensuel': 'Monthly reminder',
    'Preparation pour un rappel de suivi':
        'Preparation for a tracking reminder',
    'MySold aide a suivre comptes, transactions, categories, investissements et limites budgetaires.':
        'MySold helps track accounts, transactions, categories, investments and budget limits.',
    'Application en developpement actif.':
        'Application under active development.',
    'PIN, verrouillage et affichage discret':
        'PIN, locking and privacy display',
    'Nom, prenom et telephone': 'Name, first name and phone',
    'Alertes locales et rappels': 'Local alerts and reminders',
    'Version et informations app': 'Version and app information',
    'Annuler': 'Cancel',
    'Confirmer': 'Confirm',
    'Enregistrer': 'Save',
    'Modifier': 'Edit',
    'Supprimer': 'Delete',
    'Ajouter': 'Add',
    'Fermer': 'Close',
    'Appliquer': 'Apply',
    'Reinitialiser': 'Reset',
    'Erreur': 'Error',
    'Compte': 'Account',
    'Compte destination': 'Destination account',
    'Compte source': 'Source account',
    'Comptes': 'Accounts',
    'Categorie': 'Category',
    'Categories': 'Categories',
    'Investissement': 'Investment',
    'Investissements': 'Investments',
    'Actif': 'Asset',
    'Alerte': 'Alert',
    'Simulation': 'Simulation',
    'Gestion des comptes': 'Account management',
    'Gestion des categories': 'Category management',
    'Gestion des investissements': 'Investment management',
    'Limites budgetaires': 'Budget limits',
    'Ce compte est utilise par des transactions ou investissements.':
        'This account is used by transactions or investments.',
    'Confirmez votre PIN avant de supprimer ce compte.':
        'Confirm your PIN before deleting this account.',
    'Confirmez votre PIN avant de supprimer cette categorie.':
        'Confirm your PIN before deleting this category.',
    'Confirmez votre PIN avant de supprimer cet investissement.':
        'Confirm your PIN before deleting this investment.',
    'La categorie Others est protegee': 'The Others category is protected',
    'Cette categorie est utilisee par des transactions.':
        'This category is used by transactions.',
    'Cet investissement est utilise ou possede encore un solde.':
        'This investment is used or still has a balance.',
    'Aucun compte': 'No account',
    'Aucun actif': 'No asset',
    'Aucune depense': 'No expense',
    'Aucun revenu': 'No income',
    'Categories de depenses': 'Expense categories',
    'Categories de revenus': 'Income categories',
    'Portefeuille investi': 'Invested portfolio',
    'Ajoutez votre premier compte bancaire pour commencer a suivre votre solde.':
        'Add your first bank account to start tracking your balance.',
    'Ajoutez une categorie pour organiser vos transactions.':
        'Add a category to organize your transactions.',
    'Ajoutez OR, ETF, crypto ou tout autre support pour suivre votre portefeuille.':
        'Add gold, ETF, crypto or any other asset to track your portfolio.',
    'Ajouter un compte': 'Add an account',
    'Ajouter une categorie': 'Add a category',
    'Ajouter un actif': 'Add an asset',
    'Ajouter une alerte': 'Add an alert',
    'Nouveau compte': 'New account',
    'Modifier le compte': 'Edit account',
    'Nouvel investissement': 'New investment',
    'Modifier l investissement': 'Edit investment',
    'Code PIN': 'PIN code',
    'Suivant': 'Next',
    'Preferences utilisateur': 'User preferences',
    'Selectionnez votre devise': 'Select your currency',
    'Selectionnez votre langue': 'Select your language',
    'Selectionnez votre theme': 'Select your theme',
    'Creation du compte': 'Account creation',
    'Completez chaque section pour securiser votre espace MySold.':
        'Complete each section to secure your MySold space.',
    'Informations personnelles': 'Personal information',
    'Informations du compte': 'Account information',
    'Confirmer le mot de passe': 'Confirm password',
    'Veuillez remplir tous les champs personnels.':
        'Please fill in all personal fields.',
    'Adresse email invalide.': 'Invalid email address.',
    'Le mot de passe doit contenir au moins 1 majuscule, 1 chiffre et 1 caractere special.':
        'The password must contain at least 1 uppercase letter, 1 digit and 1 special character.',
    'Les mots de passe ne correspondent pas.': 'Passwords do not match.',
    'Veuillez remplir tous les champs du compte.':
        'Please fill in all account fields.',
    'Securite de l application': 'App security',
    'PIN (6 chiffres)': 'PIN (6 digits)',
    'Demande de reconnexion tous les...': 'Ask for reconnection every...',
    'Le code PIN doit contenir 6 chiffres.':
        'The PIN code must contain 6 digits.',
    'Veuillez completer toutes les sections.': 'Please complete all sections.',
    'Erreur lors de la creation du compte': 'Error while creating the account',
    'Creer votre PIN': 'Create your PIN',
    'Choisissez un code a 6 chiffres pour securiser votre espace.':
        'Choose a 6-digit code to secure your space.',
    'Entrez votre code a 6 chiffres pour deverrouiller vos donnees.':
        'Enter your 6-digit code to unlock your data.',
    'Deverrouiller': 'Unlock',
    'Verification...': 'Checking...',
    'Creer mon PIN': 'Create my PIN',
    'PIN incorrect': 'Incorrect PIN',
    'Deconnexion': 'Sign out',
    'Mot de passe oublie': 'Forgot password',
    'Mot de passe oublie ?': 'Forgot password?',
    'Mot de passe': 'Password',
    'Email': 'Email',
    'Envoyer': 'Send',
    'Connexion': 'Sign in',
    'Connexion...': 'Signing in...',
    'Connexion Google...': 'Google sign-in...',
    'Continuer avec Google': 'Continue with Google',
    'Se souvenir de moi': 'Remember me',
    'Afficher': 'Show',
    'Masquer': 'Hide',
    'ou': 'or',
    'Connectez-vous a votre espace bancaire.': 'Sign in to your banking space.',
    'Erreur de connexion': 'Sign-in error',
    'Veuillez entrer un email valide': 'Please enter a valid email',
    'Email de reinitialisation envoye': 'Reset email sent',
    "Impossible d'envoyer l'email pour le moment":
        'Unable to send the email right now',
    'Entrez votre email. Si un compte y est associe, un lien de reinitialisation vous sera envoye.':
        'Enter your email. If an account is associated with it, a reset link will be sent.',
    'Connexion Google annulee ou impossible':
        'Google sign-in cancelled or unavailable',
    'Creer un compte': 'Create account',
    'Creer mon compte': 'Create my account',
    'Graphique masque': 'Chart hidden',
    'Montants masques': 'Amounts hidden',
    'Montants visibles': 'Amounts visible',
    'Mode discret actif dans les parametres':
        'Privacy mode is enabled in settings',
    'Solde total': 'Total balance',
    'Solde total des comptes': 'Total account balance',
    'Vue globale': 'Global view',
    'Revenus annuels': 'Annual income',
    'Depenses annuelles': 'Annual expenses',
    'Balance annuelle': 'Annual balance',
    'Aucun compte disponible.': 'No account available.',
    'Revenus vs depenses': 'Income vs expenses',
    'Depenses par categorie': 'Expenses by category',
    'Aucune depense pour cette annee.': 'No expense for this year.',
    'Lecture rapide': 'Quick reading',
    'Moyenne revenus': 'Average income',
    'Moyenne depenses': 'Average expenses',
    'Meilleur mois': 'Best month',
    'Mois le plus depensier': 'Highest spending month',
    'Revenus': 'Income',
    'Depenses': 'Expenses',
    'Depense': 'Expense',
    'Revenu': 'Income',
    'Transfert': 'Transfer',
    'Transferts': 'Transfers',
    'Transactions': 'Transactions',
    'Transaction': 'Transaction',
    'Transactions mensuelles': 'Monthly transactions',
    'Effacer': 'Clear',
    'Aucune transaction ne correspond aux filtres.':
        'No transaction matches the filters.',
    'Aucune transaction sur cette periode.': 'No transaction for this period.',
    'Toutes les categories': 'All categories',
    'Tous les comptes': 'All accounts',
    'Montant min': 'Minimum amount',
    'Montant max': 'Maximum amount',
    'Trier par': 'Sort by',
    'Date': 'Date',
    'Description': 'Description',
    'Montant': 'Amount',
    'Filtrer par categorie': 'Filter by category',
    'Trier les transactions': 'Sort transactions',
    'Exporter le mois en CSV': 'Export month as CSV',
    'Exporter le mois en PDF': 'Export month as PDF',
    'Patrimoine': 'Net worth',
    'Taux epargne': 'Savings rate',
    'Projection fin mois': 'End-of-month projection',
    'Top depense': 'Top expense',
    'Evolution du patrimoine annuel': 'Annual net worth evolution',
    'Comparaison mois precedent': 'Previous month comparison',
    'Projection fin de mois': 'End-of-month projection',
    'Top depenses': 'Top expenses',
    'Revenus recurrents': 'Recurring income',
    'Aucune depense ce mois-ci.': 'No expense this month.',
    'Aucun revenu recurrent detecte pour le moment.':
        'No recurring income detected yet.',
    'Reel': 'Actual',
    'Projection': 'Projection',
    'Solde net': 'Net balance',
    'Basee sur le rythme quotidien du mois en cours.':
        'Based on the daily pace of the current month.',
    'mois detectes': 'months detected',
    'Gestion': 'Management',
    'Outils': 'Tools',
    'Soldes et banques': 'Balances and banks',
    'Revenus et depenses': 'Income and expenses',
    'Actifs et supports': 'Assets and supports',
    'Limites': 'Limits',
    'Alertes budget': 'Budget alerts',
    'Projection budget et investissement': 'Budget and investment projection',
    'Budget, investissement et prêt': 'Budget, investment and loan',
    'Theme, langue, devise et securite':
        'Theme, language, currency and security',
    'Espace personnel MySold': 'MySold personal space',
    'Aucune donnee pour ce graphique': 'No data for this chart',
    'Rechercher une transaction': 'Search a transaction',
    'Recherche': 'Search',
    'Filtrer et trier': 'Filter and sort',
    'Exporter': 'Export',
    'Export PDF': 'PDF export',
    'Rapport annuel, mensuel ou personnalise':
        'Annual, monthly or custom report',
    'Exporter un rapport': 'Export a report',
    'Periode': 'Period',
    'Annee complete': 'Full year',
    'Ce mois-ci': 'This month',
    'Periode personnalisee': 'Custom period',
    'Contenu du rapport': 'Report content',
    'Generer le PDF': 'Generate PDF',
    'Le rapport sera genere en arriere-plan.':
        'The report will be generated in the background.',
    'Generation du rapport': 'Report generation',
    'Preparation du rapport...': 'Preparing report...',
    'Chargement des references...': 'Loading references...',
    'Chargement des transactions...': 'Loading transactions...',
    'Preparation des donnees...': 'Preparing data...',
    'Generation du PDF...': 'Generating PDF...',
    'Enregistrement du fichier...': 'Saving file...',
    'Telechargement lance.': 'Download started.',
    'Fichier enregistre.': 'File saved.',
    'Retour': 'Back',
    'Aucune transaction a exporter.': 'No transaction to export.',
    'Export impossible': 'Export failed',
    'Supprimer le compte': 'Delete account',
    'Supprimer la categorie': 'Delete category',
    'Supprimer l investissement': 'Delete investment',
    'Suppression protegee': 'Protected deletion',
    'Confirmation PIN': 'PIN confirmation',
    'Jamais': 'Never',
    'Toujours': 'Always',
    'Immediat': 'Immediately',
    'Masquer les montants': 'Hide amounts',
    'Graphiques': 'Charts',
    'Compte protege': 'Protected account',
    'Compte enregistre': 'Account saved',
    'Categorie enregistree': 'Category saved',
    'Investissement enregistre': 'Investment saved',
    'Mettre a jour': 'Update',
    'Ajuster le compte': 'Adjust account',
    'Le solde sera affiche avec la devise {currency} dans toute l application.':
        'The balance will be displayed with the {currency} currency across the app.',
    'Nom du compte': 'Account name',
    'Ex: BOURSORAMA': 'E.g. BOURSORAMA',
    'Ex: Compte courant principal': 'E.g. Main current account',
    'Entrez un nom de compte': 'Enter an account name',
    'Solde actuel': 'Current balance',
    'Solde initial': 'Initial balance',
    'Entrez un solde': 'Enter a balance',
    'Solde invalide': 'Invalid balance',
    'Nouvelle categorie': 'New category',
    'Modifier la categorie': 'Edit category',
    'Ajuster la categorie': 'Adjust category',
    'Creer une categorie': 'Create category',
    'Elle apparaitra dans les depenses.': 'It will appear in expenses.',
    'Elle apparaitra dans les revenus.': 'It will appear in income.',
    'Nom de la categorie': 'Category name',
    'Ex: COURSES': 'E.g. GROCERIES',
    'Entrez un nom de categorie': 'Enter a category name',
    'Personnalisation': 'Customization',
    'Couleur': 'Color',
    'Icone': 'Icon',
    'Choisir une icone': 'Choose an icon',
    'Rechercher une icone': 'Search an icon',
    'Aucun resultat pour :': 'No result for:',
    'Choisir une couleur': 'Choose a color',
    'Couleur personnalisee': 'Custom color',
    'Valider': 'Validate',
    'Ajuster l actif': 'Adjust asset',
    'Creer un actif': 'Create asset',
    'Le montant evolue avec les operations d investissement.':
        'The amount changes with investment operations.',
    'Nom de l investissement': 'Investment name',
    'Ex: OR, ETF WORLD, BTC': 'E.g. GOLD, WORLD ETF, BTC',
    'Ex: Or physique ou ETF capitalisant':
        'E.g. physical gold or accumulating ETF',
    'Entrez un nom d investissement': 'Enter an investment name',
    'Compte de detention': 'Holding account',
    'Choisir un compte': 'Choose an account',
    'Sans nom': 'Unnamed',
    'Ajouter une operation': 'Add operation',
    'Selectionnez un compte et une categorie valides.':
        'Select a valid account and category.',
    'Selectionnez deux comptes valides.': 'Select two valid accounts.',
    'Les comptes doivent etre differents': 'Accounts must be different',
    'Le montant doit etre superieur a 0.': 'The amount must be greater than 0.',
    'Modifier la transaction': 'Edit transaction',
    'Nouvelle transaction': 'New transaction',
    'Entrer un montant': 'Enter an amount',
    'Montant invalide': 'Invalid amount',
    'Changer la date': 'Change date',
    'Type': 'Type',
    'Autre': 'Other',
    'Voulez-vous vraiment supprimer cette transaction ?':
        'Do you really want to delete this transaction?',
    'Nouveau transfert': 'New transfer',
    'Modifier le transfert': 'Edit transfer',
    'Selectionner un compte': 'Select an account',
    'Choisir un compte source': 'Choose a source account',
    'Choisir un compte destination': 'Choose a destination account',
    "Vous avez besoin d'au moins deux comptes pour effectuer un transfert.":
        'You need at least two accounts to make a transfer.',
    'Voulez-vous vraiment supprimer ce transfert ?':
        'Do you really want to delete this transfer?',
    'Veuillez selectionner les comptes et un investissement.':
        'Please select the accounts and an investment.',
    'Aucun compte ou investissement disponible.':
        'No account or investment available.',
    'Le compte source et le compte destination doivent etre differents.':
        'The source account and destination account must be different.',
    'Compte qui recoit l investissement': 'Account receiving the investment',
    'Choisir un compte different': 'Choose a different account',
    'Destination (action, fonds...)': 'Destination (stock, fund...)',
    'Compte support': 'Support account',
    'Compte investissement': 'Investment account',
    'Compte investissement auto': 'Automatic investment account',
    'Compte gere par les investissements': 'Account managed by investments',
    'Compte inconnu': 'Unknown account',
    'Supprimer cette operation investissement ?':
        'Delete this investment operation?',
    'Aucune nouvelle alerte declenchee': 'No new alert triggered',
    '{count} alerte(s) declenchee(s)': '{count} alert(s) triggered',
    'Depenses mensuelles': 'Monthly expenses',
    'Nouvelle alerte': 'New alert',
    'Modifier l alerte': 'Edit alert',
    'Nom de l alerte': 'Alert name',
    'Ex: Attention aux depenses': 'E.g. Watch your expenses',
    'Seuil': 'Threshold',
    'Alerte active': 'Active alert',
    'Supprimer l alerte': 'Delete alert',
    'Cette limite budgetaire sera supprimee.':
        'This budget limit will be deleted.',
    'Alertes du mois': 'Monthly alerts',
    '{count} seuil(s) configure(s)': '{count} configured threshold(s)',
    'Verifier': 'Check',
    '**% des revenus depenses': '**% of income spent',
    '{percent}% des revenus depenses': '{percent}% of income spent',
    'Seuil a {percent}% des revenus': 'Threshold at {percent}% of income',
    'Alerte desactivee': 'Alert disabled',
    'Seuil atteint': 'Threshold reached',
    'En surveillance': 'Monitoring',
    'Aucune limite': 'No limit',
    'Creez un seuil pour surveiller vos depenses par rapport aux revenus du mois.':
        'Create a threshold to monitor your expenses against monthly income.',
    'Actuel: **% - {amount} depenses': 'Current: **% - {amount} expenses',
    'Actuel: {percent}% - {amount} depenses':
        'Current: {percent}% - {amount} expenses',
    'Tri': 'Sort',
    'Ordre croissant': 'Ascending order',
    'Ordre decroissant': 'Descending order',
    'Controle': 'Control',
    'Le solde de ce compte sera calcule depuis les actifs.':
        'This account balance will be calculated from assets.',
    'Valeur actuelle de l actif': 'Current asset value',
    'Entrez une valeur': 'Enter a value',
    'Valeur invalide': 'Invalid value',
    'Choisir un investissement': 'Choose an investment',
    'Compte de detention manquant': 'Missing holding account',
    'Selectionner un investissement': 'Select an investment',
    'Selectionnez un investissement et un compte valides.':
        'Select a valid investment and account.',
    'Compte a compte': 'Account to account',
    'Actif vers compte': 'Asset to account',
    'Actif source': 'Source asset',
    'Retrait investissement': 'Investment withdrawal',
    'Tous': 'All',
    'Actions': 'Stocks',
    'ETF': 'ETF',
    'Crypto': 'Crypto',
    'Obligations': 'Bonds',
    'Autres': 'Other',
    'Type d actif': 'Asset type',
    'Ajoutez un actif dans cette categorie pour le retrouver ici.':
        'Add an asset in this category to find it here.',
    'Documents legaux': 'Legal documents',
    'Conditions generales d utilisation': 'Terms of use',
    'Consulter les regles d utilisation de MySold': 'Read MySold usage rules',
    'Politique de confidentialite': 'Privacy policy',
    'Comprendre comment vos donnees sont utilisees':
        'Understand how your data is used',
    'Mes donnees': 'My data',
    'Exporter mes donnees': 'Export my data',
    'Telecharger les donnees de votre espace en CSV':
        'Download your account data as CSV',
    'Importer mes donnees': 'Import my data',
    'Restaurer un export CSV MySold': 'Restore a MySold CSV export',
    'Confirmez votre PIN avant d importer des donnees.':
        'Confirm your PIN before importing data.',
    'Fichier CSV illisible.': 'Unreadable CSV file.',
    'Aucune donnee compatible a importer.': 'No compatible data to import.',
    'Import impossible': 'Import failed',
    'Import des donnees': 'Data import',
    'Preparation de l import...': 'Preparing import...',
    'Selectionnez un fichier CSV MySold.': 'Select a MySold CSV file.',
    'Choisir le fichier CSV': 'Choose CSV file',
    'Ouverture du selecteur de fichier...': 'Opening file picker...',
    'Aucun fichier selectionne.': 'No file selected.',
    'Lecture du fichier CSV...': 'Reading CSV file...',
    'Fichier charge: {name}': 'File loaded: {name}',
    'Lecture via le chemin du fichier...': 'Reading through file path...',
    'Analyse de la structure Firestore...': 'Analyzing Firestore structure...',
    'Recherche des doublons...': 'Checking duplicates...',
    'Import des documents...': 'Importing documents...',
    'Import termine.': 'Import complete.',
    'Import annule.': 'Import cancelled.',
    'Verification de {path}': 'Checking {path}',
    'En attente des taches...': 'Waiting for tasks...',
    'Import termine: {created} crees, {replaced} remplaces, {skipped} ignores.':
        'Import complete: {created} created, {replaced} replaced, {skipped} skipped.',
    'Le fichier contient {documents} documents. {duplicates} existent deja dans votre espace. Vous pourrez choisir quoi faire pour les doublons.':
        'The file contains {documents} documents. {duplicates} already exist in your space. You will be able to choose what to do with duplicates.',
    'Continuer': 'Continue',
    'Doublon detecte': 'Duplicate detected',
    'Le document existe deja: {path}': 'The document already exists: {path}',
    'Cet element existe deja: {name}': 'This item already exists: {name}',
    'Ne pas copier': 'Do not copy',
    'Ne pas copier tous les doublons': 'Do not copy all duplicates',
    'Tous remplacer les doublons': 'Replace all duplicates',
    'Supprimer mon compte et mes donnees': 'Delete my account and data',
    'Fonction en preparation': 'Feature in preparation',
    'Action irreversible avec confirmation':
        'Irreversible action with confirmation',
    'Confirmez votre PIN avant d exporter vos donnees.':
        'Confirm your PIN before exporting your data.',
    'Confirmez votre PIN avant la suppression definitive.':
        'Confirm your PIN before permanent deletion.',
    'Confirmez votre PIN pour acceder aux parametres sensibles.':
        'Confirm your PIN to access sensitive settings.',
    'Confirmez votre PIN avant de generer le PDF.':
        'Confirm your PIN before generating the PDF.',
    'Export des donnees lance.': 'Data export started.',
    'La suppression complete sera ajoutee prochainement.':
        'Full deletion will be added soon.',
    'Verification du compte': 'Account verification',
    'Supprimer definitivement le compte ?': 'Permanently delete account?',
    'Cette action est irreversible. Toutes vos donnees seront supprimees sans retour en arriere possible.':
        'This action is irreversible. All your data will be deleted with no possible rollback.',
    'Nous vous conseillons fortement d exporter vos donnees avant de continuer.':
        'We strongly recommend exporting your data before continuing.',
    'Tapez SUPPRIMER': 'Type DELETE',
    'Exporter avant': 'Export first',
    'Verification impossible. Reconnectez-vous puis reessayez.':
        'Verification failed. Sign in again and try again.',
    'Les donnees ont ete supprimees, mais le compte doit etre supprime apres reconnexion.':
        'The data was deleted, but the account must be deleted after signing in again.',
    'Suppression impossible': 'Deletion failed',
    'En continuant, vous acceptez les': 'By continuing, you accept the',
    'CGU': 'Terms',
    'et la': 'and the',
    'legal_terms_full': '''
MySold Terms of Use
Version of July 15, 2026

1. Purpose
MySold is a personal budget tracking application. It lets users enter, view and organize accounts, categories, transactions, investments, budget alerts, statistics and export reports. The app helps users visualize their personal finances, but it does not replace a bank, financial adviser, tax adviser, lawyer or accountant.

2. Acceptance
By creating an account, signing in or using MySold, the user accepts these terms. If the user does not accept them, the user must stop using the application.

3. Account and security
The user is responsible for the accuracy of the information entered, the confidentiality of login credentials and the PIN code. Any action performed from the user account is deemed to have been performed by the user. In case of suspected unauthorized access, the user should change the password and secure access immediately.

4. User-entered data
The user confirms that the data entered belongs to them or that they are authorized to use it. MySold does not verify the accuracy of balances, transactions, categories or investments entered by the user.

5. No financial advice
Information, statistics, projections, charts and reports provided by MySold are indicative only. They do not constitute financial, banking, tax, legal or investment advice. The user remains solely responsible for financial decisions, banking operations, investments, tax filings and wealth management choices.

6. Export, import and deletion
MySold allows the user to export data as CSV and generate PDF reports. The user may request deletion of the account and data from the app. Deletion is irreversible. Exporting data before deletion is strongly recommended. During import, the user must review restored data and handle duplicates proposed by the application.

7. Service availability
MySold may depend on third-party services, including Firebase and Google. The service may be temporarily interrupted for maintenance, technical incidents, service changes or provider unavailability. No permanent availability guarantee is given.

8. Prohibited use
Users must not use MySold to access another person's data, bypass security protections, disrupt the service, import unlawful data, impersonate someone else or use the application for fraudulent purposes.

9. Intellectual property
The MySold application, name, interface, texts, application logic and visual elements are protected. The user retains rights over the data they enter, but receives no right to copy, resell or exploit the application without authorization.

10. Changes
These terms may be updated to reflect changes to the app, the law or third-party services. The applicable version is the one available in the app at the time of use.

11. Contact
For any question about these terms, privacy or personal data, the user may contact the MySold publisher through the official contact address shown in the app or on the presentation website.
''',
    'privacy_policy_full': '''
MySold Privacy Policy
Version of July 15, 2026

1. Purpose
This policy explains what data MySold processes, why it is used, where it is stored and what rights the user can exercise. It is written to support GDPR principles: clear information, specified purposes, data minimization, security and user control.

2. Data collected
MySold may process account information, email address, first name, last name, phone number if provided, language, currency, theme, security settings, creation date, last connection date, app accounts, categories, investments, transactions, transfers, budget alerts, exports and data required for authentication.

3. Financial data
Amounts, accounts, transactions, investments and categories entered in MySold are practically sensitive because they relate to the user's personal financial situation. MySold uses them only to provide tracking, display, statistics, alerts, export, import and deletion features requested by the user.

4. Purposes
Data is used to create and secure the account, synchronize data across devices, display monthly and global views, calculate statistics, manage local budget alerts, generate CSV/PDF exports, import data, apply user preferences and protect the account.

5. Legal basis
Processing is mainly based on performance of the service requested by the user, consent during account creation and the legitimate interest of securing the app, preventing abuse and maintaining the service.

6. Storage and providers
Data is stored in Firebase, including Firebase Authentication and Cloud Firestore. Google authentication may be used if the user chooses Google sign-in. These services are provided by Google/Firebase and may involve technical processing required for hosting, security and synchronization.

7. Data sharing
MySold does not sell user personal data. Data is not transferred to commercial third parties. It may be processed by technical providers required to operate the service or disclosed where legally required.

8. Security
MySold uses several security measures: Firebase authentication, local PIN for sensitive actions, PIN checks before export/import/deletion, privacy mode to hide amounts, Firestore rules limited to the authenticated user and voluntary export by the user. No security measure is absolute, so the user must also protect the device, password and Google or email account.

9. Retention
Data is kept while the user account exists or while necessary to operate the service. The last connection date may be used to detect inactivity. In the future, MySold may delete accounts and data after a long inactivity period, for example three years, after prior notice when technically possible.

10. Export and portability
The user can export data from the app as CSV. The file contains a structure describing Firestore collections, documents, fields and paths to help reimport or portability.

11. Deletion
The user can request account and data deletion from the Security and privacy page. This action deletes known data from the user space and the authentication account when Firebase allows it. It is irreversible. Exporting data first is strongly recommended.

12. User rights
In line with GDPR principles, the user may request access, rectification, export, deletion, restriction or objection where applicable. Several rights can already be exercised directly in the app through export, editing and deletion features.

13. Minors
MySold is intended for personal use by users able to manage financial data. Minors should only use the app with approval from their legal representative.

14. Changes
This policy may change to reflect app, provider or legal updates. The applicable version is the one shown in the app.

15. Contact
For any personal data request, the user may contact the MySold publisher through the official contact address shown in the app or on the presentation website.
''',
    'MySold est une application de suivi budgetaire personnel. Les donnees saisies doivent vous appartenir ou etre utilisees avec autorisation. L application ne fournit pas de conseil financier, fiscal ou juridique. Vous restez responsable des informations saisies et de vos decisions.':
        'MySold is a personal budget tracking app. The data entered must belong to you or be used with authorization. The app does not provide financial, tax, or legal advice. You remain responsible for the information entered and your decisions.',
    'MySold traite les informations necessaires au fonctionnement de votre espace: profil, comptes, categories, investissements, transactions, preferences et alertes. Ces donnees sont stockees dans Firebase et associees a votre compte authentifie. Vous pouvez demander l export de vos donnees depuis cette page. La suppression complete du compte sera ajoutee prochainement.':
        'MySold processes the information required to run your account: profile, accounts, categories, investments, transactions, preferences, and alerts. This data is stored in Firebase and linked to your authenticated account. You can export your data from this page. Full account deletion will be added soon.',
    "Vous avez besoin d'au moins un investissement configure.":
        'You need at least one configured investment.',
    'Un compte auto gere ne peut pas etre modifie directement. Son solde evolue uniquement avec la valeur des actifs et les operations d investissement.':
        'An auto-managed account cannot be edited directly. Its balance only changes through asset values and investment operations.',
    'Auto': 'Auto',
  },
  'es': {
    'Mois': 'Mes',
    'Global': 'Global',
    'Stats': 'Estadísticas',
    'Profil': 'Perfil',
    'Parametres': 'Ajustes',
    'Langue': 'Idioma',
    'Devise': 'Moneda',
    'Annuler': 'Cancelar',
    'Confirmer': 'Confirmar',
    'Enregistrer': 'Guardar',
    'Modifier': 'Editar',
    'Supprimer': 'Eliminar',
    'Ajouter': 'Añadir',
    'Fermer': 'Cerrar',
    'Compte': 'Cuenta',
    'Comptes': 'Cuentas',
    'Categorie': 'Categoría',
    'Categories': 'Categorías',
    'Investissement': 'Inversión',
    'Investissements': 'Inversiones',
    'Gestion des comptes': 'Gestión de cuentas',
    'Gestion des categories': 'Gestión de categorías',
    'Gestion des investissements': 'Gestión de inversiones',
    'Limites budgetaires': 'Límites presupuestarios',
    'Code PIN': 'Código PIN',
    'Deverrouiller': 'Desbloquear',
    'Deconnexion': 'Cerrar sesión',
    'Mot de passe': 'Contraseña',
    'Mot de passe oublie ?': '¿Olvidaste la contraseña?',
    'Creer un compte': 'Crear una cuenta',
    'Graphique masque': 'Gráfico oculto',
    'Montants masques': 'Importes ocultos',
    'Montants visibles': 'Importes visibles',
    'Revenus': 'Ingresos',
    'Depenses': 'Gastos',
    'Depense': 'Gasto',
    'Revenu': 'Ingreso',
    'Transfert': 'Transferencia',
    'Patrimoine': 'Patrimonio',
  },
  'de': {
    'Mois': 'Monat',
    'Global': 'Gesamt',
    'Stats': 'Statistiken',
    'Profil': 'Profil',
    'Parametres': 'Einstellungen',
    'Langue': 'Sprache',
    'Devise': 'Währung',
    'Annuler': 'Abbrechen',
    'Confirmer': 'Bestätigen',
    'Enregistrer': 'Speichern',
    'Modifier': 'Bearbeiten',
    'Supprimer': 'Löschen',
    'Ajouter': 'Hinzufügen',
    'Compte': 'Konto',
    'Comptes': 'Konten',
    'Categorie': 'Kategorie',
    'Categories': 'Kategorien',
    'Investissement': 'Investition',
    'Investissements': 'Investitionen',
    'Code PIN': 'PIN-Code',
    'Mot de passe': 'Passwort',
    'Creer un compte': 'Konto erstellen',
    'Graphique masque': 'Diagramm ausgeblendet',
    'Revenus': 'Einnahmen',
    'Depenses': 'Ausgaben',
    'Depense': 'Ausgabe',
    'Revenu': 'Einnahme',
    'Transfert': 'Überweisung',
  },
  'it': {
    'Mois': 'Mese',
    'Global': 'Globale',
    'Stats': 'Statistiche',
    'Profil': 'Profilo',
    'Parametres': 'Impostazioni',
    'Langue': 'Lingua',
    'Devise': 'Valuta',
    'Annuler': 'Annulla',
    'Confirmer': 'Conferma',
    'Enregistrer': 'Salva',
    'Modifier': 'Modifica',
    'Supprimer': 'Elimina',
    'Ajouter': 'Aggiungi',
    'Compte': 'Conto',
    'Comptes': 'Conti',
    'Categorie': 'Categoria',
    'Categories': 'Categorie',
    'Investissement': 'Investimento',
    'Investissements': 'Investimenti',
    'Code PIN': 'Codice PIN',
    'Mot de passe': 'Password',
    'Creer un compte': 'Crea account',
    'Graphique masque': 'Grafico nascosto',
    'Revenus': 'Entrate',
    'Depenses': 'Spese',
    'Depense': 'Spesa',
    'Revenu': 'Entrata',
    'Transfert': 'Trasferimento',
  },
  'ja': {
    'Mois': '月',
    'Global': '全体',
    'Stats': '統計',
    'Profil': 'プロフィール',
    'Parametres': '設定',
    'Langue': '言語',
    'Devise': '通貨',
    'Annuler': 'キャンセル',
    'Confirmer': '確認',
    'Enregistrer': '保存',
    'Modifier': '編集',
    'Supprimer': '削除',
    'Ajouter': '追加',
    'Compte': '口座',
    'Comptes': '口座',
    'Categorie': 'カテゴリ',
    'Categories': 'カテゴリ',
    'Investissement': '投資',
    'Investissements': '投資',
    'Code PIN': 'PINコード',
    'Mot de passe': 'パスワード',
    'Creer un compte': 'アカウント作成',
    'Graphique masque': 'グラフ非表示',
    'Revenus': '収入',
    'Depenses': '支出',
    'Depense': '支出',
    'Revenu': '収入',
    'Transfert': '振替',
  },
};
