class WalletModel {
  final String id;
  final double balance;
  final double reserved;
  final String currency;

  const WalletModel({
    required this.id,
    required this.balance,
    required this.reserved,
    required this.currency,
  });

  factory WalletModel.fromJson(Map<String, dynamic> json) => WalletModel(
        id: json['id'] ?? '',
        balance: (json['balance'] ?? 0).toDouble(),
        reserved: (json['reserved'] ?? 0).toDouble(),
        currency: json['currency'] ?? 'USD',
      );

  String get balanceLabel => 'Rs ${balance.toStringAsFixed(0)}';
  String get reservedLabel => 'Rs ${reserved.toStringAsFixed(0)}';
}

class WalletTransactionModel {
  final String id;
  final String type;
  final double amount;
  final String description;
  final DateTime createdAt;
  final String? userName;
  final String? userEmail;

  const WalletTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.userName,
    this.userEmail,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) => WalletTransactionModel(
        id: json['id'] ?? '',
        type: json['type'] ?? '',
        amount: (json['amount'] ?? 0).toDouble(),
        description: json['description'] ?? '',
        createdAt: DateTime.tryParse(json['createdAt'] ?? json['created_at'] ?? '') ?? DateTime.now(),
        userName: json['userName'],
        userEmail: json['userEmail'],
      );

  String get amountLabel => 'Rs ${amount.toStringAsFixed(0)}';
}
