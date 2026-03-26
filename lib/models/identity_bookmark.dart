class IdentityBookmark {
  final String name;
  final String publicKey;

  IdentityBookmark({required this.name, required this.publicKey});

  Map<String, String> toJson() => {
        'name': name,
        'publicKey': publicKey,
      };

  factory IdentityBookmark.fromJson(Map<String, dynamic> json) => IdentityBookmark(
        name: json['name'] as String,
        publicKey: json['publicKey'] as String,
      );
}
