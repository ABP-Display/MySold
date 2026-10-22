// firestore_service.dart

import 'package:mysold/data/document_store.dart';
import 'package:flutter/material.dart';
import 'package:mysold/models/transaction_model.dart';
import 'package:mysold/services/app_logger.dart';

// Firestore structure per user:

// users (collection)
// [userId] (document)
// accounts (subcollection)
// [accountId] → {
// name: string,         // e.g. "Boursorama"
// amount: number        // e.g. 1200.00
// }

// categories (subcollection)
// [categoryId] → {
// name: string,         // e.g. "Groceries"
// type: array<string>   // e.g. ["expense"], or ["income", "expense"]
// }

// transactions (subcollection)
// [transactionId] → {
// amount: number,        // e.g. -23.34
// date: timestamp,       // e.g. 2025-05-24T23:15:45Z
// description: string,   // e.g. "Carrefour"
// accountId: string,     // e.g. "accountId" (reference to user's account)
// categoryId: string     // e.g. "categoryId" (reference to user's category)
// }

class BudgetService {
  final String userId;
  final DocumentStore _firestore = DocumentStore.instance;

  BudgetService({required this.userId});

  CollectionReference<Map<String, dynamic>> get _transactions =>
      _firestore.collection('users').doc(userId).collection('transactions');

  CollectionReference<Map<String, dynamic>> get _accounts =>
      _firestore.collection('users').doc(userId).collection('accounts');

  CollectionReference<Map<String, dynamic>> get _categories =>
      _firestore.collection('users').doc(userId).collection('categories');

  CollectionReference<Map<String, dynamic>> get _investments =>
      _firestore.collection('users').doc(userId).collection('investments');

  Future<DocumentSnapshot<Map<String, dynamic>>> _requireAccount(
    String? accountId,
    String label,
  ) async {
    if (accountId == null || accountId.isEmpty) {
      throw Exception('$label manquant.');
    }

    final snapshot = await _accounts.doc(accountId).get();
    if (!snapshot.exists) {
      throw Exception('$label introuvable ou supprime.');
    }
    return snapshot;
  }

  Future<void> _requireCategory(String? categoryId, String type) async {
    if (categoryId == null || categoryId.isEmpty) {
      throw Exception('Categorie manquante.');
    }

    final snapshot = await _categories.doc(categoryId).get();
    final data = snapshot.data();
    if (!snapshot.exists || data == null) {
      throw Exception('Categorie introuvable ou supprimee.');
    }
    if (data['type'] != type) {
      throw Exception('La categorie ne correspond pas au type de transaction.');
    }
  }

  Future<void> _requireInvestment(String? investmentId) async {
    if (investmentId == null || investmentId.isEmpty) {
      throw Exception('Investissement manquant.');
    }

    final snapshot = await _investments.doc(investmentId).get();
    if (!snapshot.exists) {
      throw Exception('Investissement introuvable ou supprime.');
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> _requireInvestmentDoc(
    String? investmentId,
  ) async {
    if (investmentId == null || investmentId.isEmpty) {
      throw Exception('Investissement manquant.');
    }

    final snapshot = await _investments.doc(investmentId).get();
    if (!snapshot.exists) {
      throw Exception('Investissement introuvable ou supprime.');
    }
    return snapshot;
  }

  double _balanceOf(DocumentSnapshot<Map<String, dynamic>> account) {
    return _roundMoney(((account.data()?['balance'] ?? 0) as num).toDouble());
  }

  double _roundMoney(double value) {
    return double.parse(value.toStringAsFixed(2));
  }

  void _ensureManualAccount(
    DocumentSnapshot<Map<String, dynamic>> account,
    String label,
  ) {
    if (account.data()?['managedByInvestments'] == true) {
      throw Exception(
        '$label est gere par les investissements et ne peut pas etre modifie manuellement.',
      );
    }
  }

  Future<void> _ensureSufficientBalance({
    required String accountId,
    required double amount,
    double creditBack = 0,
    String message = 'Solde insuffisant.',
  }) async {
    final account = await _requireAccount(accountId, 'Compte source');
    final available = _balanceOf(account) + creditBack;
    if (available < amount) {
      throw Exception(message);
    }
  }

  Future<void> _validateTransactionForWrite(
    TransactionModel transaction, {
    TransactionModel? oldTransaction,
  }) async {
    if (transaction.amount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }

    if (transaction.type == 'income') {
      final account = await _requireAccount(transaction.fromAccountId, 'Compte');
      _ensureManualAccount(account, 'Compte');
      await _requireCategory(transaction.categoryId, 'income');
      return;
    }

    if (transaction.type == 'expense') {
      final accountId = transaction.fromAccountId;
      final account = await _requireAccount(accountId, 'Compte');
      _ensureManualAccount(account, 'Compte');
      await _requireCategory(transaction.categoryId, 'expense');

      final creditBack =
          oldTransaction?.type == 'expense' &&
              oldTransaction?.fromAccountId == accountId
          ? oldTransaction!.amount
          : 0.0;
      await _ensureSufficientBalance(
        accountId: accountId!,
        amount: transaction.amount,
        creditBack: creditBack,
        message: 'Solde insuffisant pour cette depense.',
      );
      return;
    }

    if (transaction.type == 'investment') {
      final sourceAccountId = transaction.fromAccountId;
      var destinationAccountId = transaction.toAccountId;
      final sourceAccount = await _requireAccount(
        sourceAccountId,
        'Compte source',
      );
      _ensureManualAccount(sourceAccount, 'Compte source');
      final investment = await _requireInvestmentDoc(transaction.investmentId);
      final configuredAccountId =
          investment.data()?['holdingAccountId']?.toString();
      if (configuredAccountId == null || configuredAccountId.isEmpty) {
        throw Exception(
          'Cet investissement doit avoir un compte de detention configure.',
        );
      }
      destinationAccountId ??= configuredAccountId;
      if (destinationAccountId != configuredAccountId) {
        throw Exception(
          'Le compte support doit correspondre au compte configure sur l actif.',
        );
      }
      await _requireAccount(destinationAccountId, 'Compte support');

      if (sourceAccountId == destinationAccountId) {
        throw Exception(
          'Le compte source et le compte support doivent etre differents.',
        );
      }

      final creditBack =
          oldTransaction?.type == 'investment' &&
              oldTransaction?.fromAccountId == sourceAccountId
          ? oldTransaction!.amount
          : 0.0;
      await _ensureSufficientBalance(
        accountId: sourceAccountId!,
        amount: transaction.amount,
        creditBack: creditBack,
        message: 'Solde insuffisant pour cet investissement.',
      );
      return;
    }

    throw Exception('Type de transaction non pris en charge.');
  }

  //
  // ➕ Ajouter une transaction classique (revenu/dépense)
  Future<void> addTransaction(TransactionModel transaction) async {
    await _validateTransactionForWrite(transaction);

    final transactionRef = _transactions.doc();

    final batch = _firestore.batch();
    final transactionData = transaction.toMap();

    if (transaction.type == 'income') {
      batch.update(_accounts.doc(transaction.fromAccountId), {
        'balance': FieldValue.increment(transaction.amount),
      });
    } else if (transaction.type == 'expense') {
      batch.update(_accounts.doc(transaction.fromAccountId!), {
        'balance': FieldValue.increment(-transaction.amount),
      });
    } else if (transaction.type == 'investment') {
      if (transaction.fromAccountId == null ||
          transaction.investmentId == null) {
        throw Exception(
          "Compte source, compte investissement ou investissement manquant.",
        );
      }
      final investment = await _requireInvestmentDoc(transaction.investmentId);
      final destinationAccountId =
          transaction.toAccountId ??
          investment.data()?['holdingAccountId']?.toString();
      if (destinationAccountId == null || destinationAccountId.isEmpty) {
        throw Exception(
          'Cet investissement doit avoir un compte de detention configure.',
        );
      }
      transactionData['toAccountId'] = destinationAccountId;
      batch.update(_accounts.doc(transaction.fromAccountId!), {
        'balance': FieldValue.increment(-transaction.amount),
      });
      batch.update(_accounts.doc(destinationAccountId), {
        'balance': FieldValue.increment(transaction.amount),
      });
      batch.update(_investments.doc(transaction.investmentId!), {
        'balance': FieldValue.increment(transaction.amount),
        'holdingAccountId': destinationAccountId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.set(transactionRef, transactionData);
    await batch.commit();
  }

  //
  // 🔁 Mettre à jour une transaction
  Future<void> updateTransaction(
    TransactionModel oldTx,
    TransactionModel newTx,
  ) async {
    if (oldTx.id == null) return;
    await _validateTransactionForWrite(newTx, oldTransaction: oldTx);

    final batch = _firestore.batch();
    final txRef = _transactions.doc(oldTx.id);

    // Annule l'ancienne transaction
    if (oldTx.type == 'income') {
      batch.update(_accounts.doc(oldTx.fromAccountId), {
        'balance': FieldValue.increment(-oldTx.amount),
      });
    } else if (oldTx.type == 'expense') {
      batch.update(_accounts.doc(oldTx.fromAccountId!), {
        'balance': FieldValue.increment(oldTx.amount),
      });
    } else if (oldTx.type == 'investment') {
      if (oldTx.fromAccountId == null || oldTx.investmentId == null) {
        throw Exception("Ancien investissement incomplet.");
      }
      batch.update(_accounts.doc(oldTx.fromAccountId!), {
        'balance': FieldValue.increment(oldTx.amount),
      });
      if (oldTx.toAccountId != null) {
        batch.update(_accounts.doc(oldTx.toAccountId!), {
          'balance': FieldValue.increment(-oldTx.amount),
        });
      }
      batch.update(_investments.doc(oldTx.investmentId!), {
        'balance': FieldValue.increment(-oldTx.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Applique la nouvelle
    if (newTx.type == 'income') {
      batch.update(_accounts.doc(newTx.fromAccountId), {
        'balance': FieldValue.increment(newTx.amount),
      });
    } else if (newTx.type == 'expense') {
      batch.update(_accounts.doc(newTx.fromAccountId!), {
        'balance': FieldValue.increment(-newTx.amount),
      });
    } else if (newTx.type == 'investment') {
      if (newTx.fromAccountId == null ||
          newTx.investmentId == null) {
        throw Exception("Nouvel investissement incomplet.");
      }
      final investment = await _requireInvestmentDoc(newTx.investmentId);
      final destinationAccountId =
          newTx.toAccountId ?? investment.data()?['holdingAccountId']?.toString();
      if (destinationAccountId == null || destinationAccountId.isEmpty) {
        throw Exception(
          'Cet investissement doit avoir un compte de detention configure.',
        );
      }
      batch.update(_accounts.doc(newTx.fromAccountId!), {
        'balance': FieldValue.increment(-newTx.amount),
      });
      batch.update(_accounts.doc(destinationAccountId), {
        'balance': FieldValue.increment(newTx.amount),
      });
      batch.update(_investments.doc(newTx.investmentId!), {
        'balance': FieldValue.increment(newTx.amount),
        'holdingAccountId': destinationAccountId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      newTx = newTx.copyWith(toAccountId: destinationAccountId);
    }

    batch.update(txRef, newTx.toMap());
    await batch.commit();
  }

  //
  // ❌ Supprimer une transaction
  Future<void> deleteTransaction(TransactionModel transaction) async {
    if (transaction.id == null) {
      AppLogger.warning('Transaction delete skipped: missing id.');
      return;
    }

    final batch = _firestore.batch();

    if (transaction.type == 'income') {
      batch.update(_accounts.doc(transaction.fromAccountId), {
        'balance': FieldValue.increment(-transaction.amount),
      });
    } else if (transaction.type == 'expense') {
      batch.update(_accounts.doc(transaction.fromAccountId!), {
        'balance': FieldValue.increment(transaction.amount),
      });
    } else if (transaction.type == 'investment') {
      if (transaction.fromAccountId == null || transaction.investmentId == null) {
        throw Exception("Investissement incomplet.");
      }
      batch.update(_accounts.doc(transaction.fromAccountId!), {
        'balance': FieldValue.increment(transaction.amount),
      });
      if (transaction.toAccountId != null) {
        batch.update(_accounts.doc(transaction.toAccountId!), {
          'balance': FieldValue.increment(-transaction.amount),
        });
      }
      batch.update(_investments.doc(transaction.investmentId!), {
        'balance': FieldValue.increment(-transaction.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    batch.delete(_transactions.doc(transaction.id!));
    await batch.commit();
  }

  //
  // ➕ Ajouter un transfert
  Future<void> addTransfer({
    required double amount,
    required DateTime date,
    required String sourceAccountId,
    required String destinationAccountId,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }
    if (sourceAccountId == destinationAccountId) {
      throw Exception('Les comptes de transfert doivent etre differents.');
    }
    final sourceAccount = await _requireAccount(sourceAccountId, 'Compte source');
    final destinationAccount = await _requireAccount(
      destinationAccountId,
      'Compte destination',
    );
    _ensureManualAccount(sourceAccount, 'Compte source');
    _ensureManualAccount(destinationAccount, 'Compte destination');
    await _ensureSufficientBalance(
      accountId: sourceAccountId,
      amount: amount,
      message: 'Solde insuffisant pour effectuer ce transfert.',
    );

    final batch = _firestore.batch();
    final docRef = _transactions.doc();

    batch.set(docRef, {
      'amount': amount,
      'categoryId': null,
      'date': Timestamp.fromDate(date),
      'description': 'Transfer',
      'fromAccountId': sourceAccountId,
      'investmentId': null,
      'toAccountId': destinationAccountId,
      'type': 'transfer',
    });

    batch.update(_accounts.doc(sourceAccountId), {
      'balance': FieldValue.increment(-amount),
    });
    batch.update(_accounts.doc(destinationAccountId), {
      'balance': FieldValue.increment(amount),
    });

    await batch.commit();
  }

  //
  // 🔁 Mettre à jour un transfert
  Future<void> updateTransfer(
    TransactionModel oldTransfer,
    TransactionModel newTransfer,
  ) async {
    if (oldTransfer.investmentId != null || newTransfer.investmentId != null) {
      await updateInvestmentWithdrawal(oldTransfer, newTransfer);
      return;
    }

    if (oldTransfer.id == null || newTransfer.id == null) return;
    if (newTransfer.amount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }
    if (newTransfer.fromAccountId == null || newTransfer.toAccountId == null) {
      throw Exception('Compte source ou destination manquant.');
    }
    if (newTransfer.fromAccountId == newTransfer.toAccountId) {
      throw Exception('Les comptes de transfert doivent etre differents.');
    }
    final newSourceAccount = await _requireAccount(
      newTransfer.fromAccountId,
      'Compte source',
    );
    final newDestinationAccount = await _requireAccount(
      newTransfer.toAccountId,
      'Compte destination',
    );
    _ensureManualAccount(newSourceAccount, 'Compte source');
    _ensureManualAccount(newDestinationAccount, 'Compte destination');

    final batch = _firestore.batch();
    final txRef = _transactions.doc(oldTransfer.id!);

    // Récupère le solde actuel du nouveau compte source
    final fromSnap = await _accounts.doc(newTransfer.fromAccountId!).get();
    var availableBalance = (fromSnap.data()?['balance'] ?? 0.0) as num;
    if (oldTransfer.fromAccountId == newTransfer.fromAccountId) {
      availableBalance += oldTransfer.amount;
    }
    if (availableBalance < newTransfer.amount) {
      throw Exception("Solde insuffisant pour effectuer ce transfert.");
    }

    // 1. Annule l'ancien transfert
    batch.update(_accounts.doc(oldTransfer.fromAccountId!), {
      'balance': FieldValue.increment(oldTransfer.amount),
    });
    batch.update(_accounts.doc(oldTransfer.toAccountId!), {
      'balance': FieldValue.increment(-oldTransfer.amount),
    });

    // 2. Applique le nouveau transfert
    batch.update(_accounts.doc(newTransfer.fromAccountId!), {
      'balance': FieldValue.increment(-newTransfer.amount),
    });
    batch.update(_accounts.doc(newTransfer.toAccountId!), {
      'balance': FieldValue.increment(newTransfer.amount),
    });

    // 3. Met à jour la transaction
    batch.update(txRef, {
      'amount': newTransfer.amount,
      'date': Timestamp.fromDate(newTransfer.date),
      'fromAccountId': newTransfer.fromAccountId,
      'toAccountId': newTransfer.toAccountId,
    });

    await batch.commit();
  }

  //
  // ❌ Supprimer un transfert
  Future<void> deleteTransfer(TransactionModel t) async {
    if (t.id == null || t.fromAccountId == null || t.toAccountId == null) {
      AppLogger.warning('Transfer delete skipped: missing required fields.');
      return;
    }

    final batch = _firestore.batch();
    final txRef = _transactions.doc(t.id!);

    if (t.investmentId != null) {
      batch.update(_accounts.doc(t.fromAccountId!), {
        'balance': FieldValue.increment(t.amount),
      });
      batch.update(_investments.doc(t.investmentId!), {
        'balance': FieldValue.increment(t.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_accounts.doc(t.toAccountId!), {
        'balance': FieldValue.increment(-t.amount),
      });
    } else {
      batch.update(_accounts.doc(t.fromAccountId!), {
        'balance': FieldValue.increment(t.amount),
      });
      batch.update(_accounts.doc(t.toAccountId!), {
        'balance': FieldValue.increment(-t.amount),
      });
    }

    batch.delete(txRef);
    
    try {
      await batch.commit();
    } catch (e) {
      AppLogger.error('Transfer delete batch failed', error: e);
    }
  }

  //
  // ➕ Ajouter un investissement
  Future<void> addInvestment({
    required double amount,
    required DateTime date,
    required String sourceAccountId,
    required String destinationAccountId,
    required String destinationInvestmentId,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }
    if (sourceAccountId == destinationAccountId) {
      throw Exception(
        'Le compte source et le compte support doivent etre differents.',
      );
    }
    await _requireAccount(sourceAccountId, 'Compte source');
    await _requireAccount(destinationAccountId, 'Compte support');
    await _requireInvestment(destinationInvestmentId);
    await _ensureSufficientBalance(
      accountId: sourceAccountId,
      amount: amount,
      message: 'Solde insuffisant pour cet investissement.',
    );

    final batch = _firestore.batch();
    final docRef = _investments.doc(destinationInvestmentId);
    final transactionRef = _transactions.doc();

    batch.set(transactionRef, {
      'amount': amount,
      'categoryId': null,
      'date': Timestamp.fromDate(date),
      'description': 'Investment',
      'fromAccountId': sourceAccountId,
      'investmentId': destinationInvestmentId,
      'toAccountId': destinationAccountId,
      'type': 'investment',
    });

    // Décrémente le compte source
    batch.update(_accounts.doc(sourceAccountId), {
      'balance': FieldValue.increment(-amount),
    });

    // Incrémente l’investissement
    batch.update(_accounts.doc(destinationAccountId), {
      'balance': FieldValue.increment(amount),
    });
    batch.update(docRef, {
      'balance': FieldValue.increment(amount),
      'holdingAccountId': destinationAccountId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  //
  // 🔁 Mettre à jour un investissement
  Future<void> updateInvestment({
    required String investmentId,
    required double oldAmount,
    required String oldSourceAccountId,
    required double newAmount,
    required DateTime newDate,
    required String newSourceAccountId,
    required String newDestinationInvestmentId,
  }) async {
    if (newAmount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }
    await _requireInvestment(investmentId);
    await _requireInvestment(newDestinationInvestmentId);
    await _requireAccount(oldSourceAccountId, 'Ancien compte source');
    await _requireAccount(newSourceAccountId, 'Nouveau compte source');
    await _ensureSufficientBalance(
      accountId: newSourceAccountId,
      amount: newAmount,
      creditBack: oldSourceAccountId == newSourceAccountId ? oldAmount : 0,
      message: 'Solde insuffisant pour cet investissement.',
    );

    final batch = _firestore.batch();
    final docRef = _investments.doc(investmentId);

    // 1. Annuler l'ancien
    batch.update(_accounts.doc(oldSourceAccountId), {
      'balance': FieldValue.increment(oldAmount),
    });

    // 2. Appliquer le nouveau
    batch.update(_accounts.doc(newSourceAccountId), {
      'balance': FieldValue.increment(-newAmount),
    });

    // 3. Mettre à jour l’investissement
    batch.update(docRef, {
      'amount': newAmount,
      'date': Timestamp.fromDate(newDate),
      'sourceAccountId': newSourceAccountId,
      'destinationInvestmentId': newDestinationInvestmentId,
    });

    await batch.commit();
  }

  //
  // ❌ Supprimer un investissement
  Future<void> deleteInvestment(TransactionModel inv) async {
    await deleteTransaction(inv);
  }

  Future<void> addInvestmentWithdrawal({
    required double amount,
    required DateTime date,
    required String investmentId,
    required String destinationAccountId,
  }) async {
    if (amount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }

    final investment = await _requireInvestmentDoc(investmentId);
    final investmentData = investment.data() ?? {};
    final holdingAccountId = investmentData['holdingAccountId']?.toString();
    if (holdingAccountId == null || holdingAccountId.isEmpty) {
      throw Exception(
        'Cet investissement doit avoir un compte de detention configure.',
      );
    }

    final destinationAccount = await _requireAccount(
      destinationAccountId,
      'Compte destination',
    );
    _ensureManualAccount(destinationAccount, 'Compte destination');

    final investmentBalance =
        ((investmentData['balance'] ?? 0) as num).toDouble();
    if (investmentBalance < amount) {
      throw Exception('Solde insuffisant sur cet investissement.');
    }

    final batch = _firestore.batch();
    final transactionRef = _transactions.doc();

    batch.set(transactionRef, {
      'amount': amount,
      'categoryId': null,
      'date': Timestamp.fromDate(date),
      'description': 'Retrait investissement',
      'fromAccountId': holdingAccountId,
      'investmentId': investmentId,
      'toAccountId': destinationAccountId,
      'type': 'transfer',
    });
    batch.update(_accounts.doc(holdingAccountId), {
      'balance': FieldValue.increment(-amount),
    });
    batch.update(_investments.doc(investmentId), {
      'balance': FieldValue.increment(-amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_accounts.doc(destinationAccountId), {
      'balance': FieldValue.increment(amount),
    });

    await batch.commit();
  }

  Future<void> updateInvestmentWithdrawal(
    TransactionModel oldTransfer,
    TransactionModel newTransfer,
  ) async {
    if (oldTransfer.id == null || newTransfer.id == null) return;
    if (newTransfer.amount <= 0) {
      throw Exception('Le montant doit etre superieur a 0.');
    }
    if (newTransfer.investmentId == null || newTransfer.toAccountId == null) {
      throw Exception('Investissement ou compte destination manquant.');
    }

    final newInvestment = await _requireInvestmentDoc(newTransfer.investmentId);
    final newInvestmentData = newInvestment.data() ?? {};
    final newHoldingAccountId =
        newInvestmentData['holdingAccountId']?.toString();
    if (newHoldingAccountId == null || newHoldingAccountId.isEmpty) {
      throw Exception(
        'Cet investissement doit avoir un compte de detention configure.',
      );
    }

    final destinationAccount = await _requireAccount(
      newTransfer.toAccountId,
      'Compte destination',
    );
    _ensureManualAccount(destinationAccount, 'Compte destination');

    final sameInvestment = oldTransfer.investmentId == newTransfer.investmentId;
    final available =
        ((newInvestmentData['balance'] ?? 0) as num).toDouble() +
            (sameInvestment ? oldTransfer.amount : 0);
    if (available < newTransfer.amount) {
      throw Exception('Solde insuffisant sur cet investissement.');
    }

    final batch = _firestore.batch();

    if (oldTransfer.investmentId != null &&
        oldTransfer.fromAccountId != null &&
        oldTransfer.toAccountId != null) {
      batch.update(_accounts.doc(oldTransfer.fromAccountId!), {
        'balance': FieldValue.increment(oldTransfer.amount),
      });
      batch.update(_investments.doc(oldTransfer.investmentId!), {
        'balance': FieldValue.increment(oldTransfer.amount),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_accounts.doc(oldTransfer.toAccountId!), {
        'balance': FieldValue.increment(-oldTransfer.amount),
      });
    }

    batch.update(_accounts.doc(newHoldingAccountId), {
      'balance': FieldValue.increment(-newTransfer.amount),
    });
    batch.update(_investments.doc(newTransfer.investmentId!), {
      'balance': FieldValue.increment(-newTransfer.amount),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_accounts.doc(newTransfer.toAccountId!), {
      'balance': FieldValue.increment(newTransfer.amount),
    });
    batch.update(_transactions.doc(oldTransfer.id!), {
      'amount': newTransfer.amount,
      'date': Timestamp.fromDate(newTransfer.date),
      'description': 'Retrait investissement',
      'fromAccountId': newHoldingAccountId,
      'investmentId': newTransfer.investmentId,
      'toAccountId': newTransfer.toAccountId,
      'type': 'transfer',
    });

    await batch.commit();
  }

  //
  // 📈 Récupérer les investissements
  Future<Map<String, String>> getInvestments() async {
    final snapshot = await _investments.get();
    return {
      for (var doc in snapshot.docs) doc.id: doc.data()['name'] ?? 'Sans nom',
    };
  }

  //
  // 📅 Récupérer les transactions d’un mois donné
  Future<List<TransactionModel>> getTransactionsForMonth(DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);

    try {
      final snapshot = await _transactions
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Monthly transactions query failed', error: e, stackTrace: stack);
      return [];
    }
  }

  //
  // 📊 Récupère les catégories
  // ✅ Nouvelle version : id -> {name, icon, color, type}
  Future<List<TransactionModel>> getTransactionsForYear(int year) async {
    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);

    try {
      final snapshot = await _transactions
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .orderBy('date')
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Yearly transactions query failed', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<List<TransactionModel>> getTransactionsBetween({
    required DateTime start,
    required DateTime end,
    bool descending = true,
  }) async {
    try {
      final snapshot = await _transactions
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .orderBy('date', descending: descending)
          .get();

      return snapshot.docs
          .map((doc) => TransactionModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e, stack) {
      AppLogger.error('Date range transactions query failed', error: e, stackTrace: stack);
      return [];
    }
  }

  Future<Map<String, Map<String, dynamic>>> getCategoriesAsMap({
    String? type,
  }) async {
    Query<Map<String, dynamic>> query = _categories;

    // Filtre optionnel par type
    if (type != null) {
      query = query.where('type', isEqualTo: type);
    }

    final snapshot = await query.get();

    // Petit helper pour convertir proprement en int (Firestore peut stocker int/num/string)
    int? toInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v);
      return null;
    }

    return {
      for (final doc in snapshot.docs)
        doc.id: {
          'name': doc.data()['name'] ?? 'Sans nom',
          'icon': toInt(
            doc.data()['icon'],
          ), // ex: 0xe87c (Material icon codePoint)
          'color': toInt(doc.data()['color']), // ex: 4283215696
          'type': doc.data()['type'], // 'income' | 'expense' | ...
        },
    };
  }

  // 🔹 Récupérer les infos d’une catégorie par son ID
  Future<Map<String, dynamic>> getCategoryById(String categoryId) async {
    final doc = await _categories.doc(categoryId).get();
    return doc.data() ?? {};
  }

  Future<bool> isAccountInUse(String accountId) async {
    final fromTransactions = await _transactions
        .where('fromAccountId', isEqualTo: accountId)
        .limit(1)
        .get();
    if (fromTransactions.docs.isNotEmpty) return true;

    final toTransactions = await _transactions
        .where('toAccountId', isEqualTo: accountId)
        .limit(1)
        .get();
    if (toTransactions.docs.isNotEmpty) return true;

    final linkedInvestments = await _investments
        .where('holdingAccountId', isEqualTo: accountId)
        .limit(1)
        .get();
    return linkedInvestments.docs.isNotEmpty;
  }

  Future<bool> isCategoryInUse(String categoryId) async {
    final transactions = await _transactions
        .where('categoryId', isEqualTo: categoryId)
        .limit(1)
        .get();
    return transactions.docs.isNotEmpty;
  }

  Future<bool> isInvestmentInUse(String investmentId) async {
    final transactions = await _transactions
        .where('investmentId', isEqualTo: investmentId)
        .limit(1)
        .get();
    if (transactions.docs.isNotEmpty) return true;

    final investment = await _investments.doc(investmentId).get();
    final balance = ((investment.data()?['balance'] ?? 0) as num).toDouble();
    return balance != 0;
  }

  //
  // 💼 Récupère les comptes
  Future<Map<String, String>> getAccounts() async {
    final snapshot = await _accounts.get();
    return {
      for (var doc in snapshot.docs) doc.id: doc.data()['name'] ?? 'Sans nom',
    };
  }

  Future<Map<String, String>> getManualAccounts() async {
    final snapshot = await _accounts.get();
    return {
      for (var doc in snapshot.docs)
        if (doc.data()['managedByInvestments'] != true)
          doc.id: doc.data()['name'] ?? 'Sans nom',
    };
  }

  //
  // ➕ Ajouter un compte
  Future<void> addAccount(String id, String name) async {
    await _accounts.doc(id).set({'name': name, 'balance': 0.0});
  }

  //
  // ➕ Ajouter une catégorie
  Future<void> addCategory(
    String id,
    String name,
    List<String> type,
    Color color,
    IconData icon,
  ) async {
    await _categories.doc(id).set({
      'name': name,
      'type': type,
      'color': color.value, // 👈 Sauvegarde en int
      'icon': icon.codePoint, // 👈 Sauvegarde en int
    });
  }
}

