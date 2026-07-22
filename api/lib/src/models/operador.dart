class Operador {
  const Operador({
    required this.matricula,
    required this.nome,
    required this.nomeGuerra,
    required this.codfilial,
    required this.permissoes,
  });

  final String matricula;
  final String nome;
  final String nomeGuerra;
  final int codfilial;
  final List<String> permissoes;

  Map<String, Object?> toJson() => {
        'matricula': matricula,
        'nome': nome,
        'nomeGuerra': nomeGuerra,
        'codfilial': codfilial,
        'permissoes': permissoes,
      };

  factory Operador.fromJson(Map<String, Object?> json) => Operador(
        matricula: json['matricula']! as String,
        nome: json['nome']! as String,
        nomeGuerra: json['nomeGuerra']! as String,
        codfilial: json['codfilial']! as int,
        permissoes: (json['permissoes']! as List).cast<String>(),
      );
}
