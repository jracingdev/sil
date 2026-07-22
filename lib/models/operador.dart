class Operador {
  const Operador({
    required this.matricula,
    required this.nome,
    required this.nomeGuerra,
    required this.codfilial,
    required this.permissoes,
    this.token,
  });

  final String matricula;
  final String nome;
  final String nomeGuerra;
  final int codfilial;
  final List<String> permissoes;
  final String? token;

  Operador copyWith({String? token}) => Operador(
    matricula: matricula,
    nome: nome,
    nomeGuerra: nomeGuerra,
    codfilial: codfilial,
    permissoes: permissoes,
    token: token ?? this.token,
  );
}
