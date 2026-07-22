class ItemPedido {
  const ItemPedido({
    required this.codauxiliar,
    required this.codfab,
    required this.desc,
    required this.m,
    required this.r,
    required this.p,
    required this.a,
    required this.qtd,
  });

  final String codauxiliar;
  final String codfab;
  final String desc;
  final String m;
  final String r;
  final String p;
  final String a;
  final int qtd;

  Map<String, Object?> toJson() => {
        'codauxiliar': codauxiliar,
        'codfab': codfab,
        'desc': desc,
        'm': m,
        'r': r,
        'p': p,
        'a': a,
        'qtd': qtd,
      };

  factory ItemPedido.fromJson(Map<String, Object?> json) => ItemPedido(
        codauxiliar: json['codauxiliar']! as String,
        codfab: json['codfab']! as String,
        desc: json['desc']! as String,
        m: json['m']! as String,
        r: json['r']! as String,
        p: json['p']! as String,
        a: json['a']! as String,
        qtd: json['qtd']! as int,
      );
}
