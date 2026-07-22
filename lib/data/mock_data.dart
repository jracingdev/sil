import '../models/operador.dart';
import '../models/pedido.dart';

const empresaCodigo = '126';

const modulos = <Modulo>[
  Modulo('picking', 'Separação de Pedido', true),
  Modulo('conferencia', 'Conferência de Recebimento', true),
  Modulo('inventario', 'Inventário Cíclico', false),
  Modulo('recontagem', 'Recontagem Cega', false),
  Modulo('enderecamento', 'Endereçamento de Produtos', false),
  Modulo('transferencia', 'Transferência entre Endereços', false),
  Modulo('consulta-estoque', 'Consulta de Estoque', false),
  Modulo('consulta-preco', 'Consulta de Preço', false),
  Modulo('fracionamento', 'Fracionamento de Pallet', false),
  Modulo('carregamento', 'Carregamento / Romaneio', false),
  Modulo('devolucao', 'Devolução de Cliente', false),
  Modulo('bloqueio-produto', 'Bloqueio de Produto', false),
  Modulo('etiquetagem', 'Reimpressão de Etiqueta', false),
  Modulo('avarias', 'Registro de Avarias', false),
  Modulo('auditoria', 'Auditoria de Separação', false),
  Modulo('consulta-pedido', 'Consulta de Pedido', false),
];

const credenciaisMock = <String, Map<String, String>>{
  'RSGUIMARAES': {
    'senha': '1234',
    'matricula': '12',
    'nome': 'Rodrigo Silva Guimarães',
    'tipo': 'S',
  },
  'JOAOSEP': {
    'senha': '1234',
    'matricula': '45',
    'nome': 'João Pereira',
    'tipo': 'S',
  },
  'MCOMPRAS': {
    'senha': '1234',
    'matricula': '77',
    'nome': 'Marcos Souza',
    'tipo': 'C',
  },
};

Operador? autenticarMock(String usuario, String senha) {
  final dados = credenciaisMock[usuario.trim().toUpperCase()];
  if (dados == null || dados['senha'] != senha || dados['tipo'] != 'S') {
    return null;
  }
  return Operador(
    matricula: dados['matricula']!,
    nome: dados['nome']!,
    nomeGuerra: usuario.trim().toUpperCase(),
    codfilial: 1,
    permissoes: const ['picking'],
    token: 'mock-session-token',
  );
}

const transportadoras = <int, TransportadoraInfo>{
  887: TransportadoraInfo(prioridade: 0, nome: 'Retira'),
  1038: TransportadoraInfo(prioridade: 1, nome: 'Motoboy'),
  313: TransportadoraInfo(prioridade: 2, nome: 'Nosso Carro'),
  1093: TransportadoraInfo(prioridade: 3, nome: 'Vendas Casada'),
};

TransportadoraInfo transportadora(int codigo) =>
    transportadoras[codigo] ??
    TransportadoraInfo(prioridade: 99, nome: 'Fornecedor $codigo');

const pedidosMock = <Pedido>[
  Pedido(
    id: '1324001',
    data: '2026-02-13',
    codFornecFrete: 887,
    cliente: 'José Pedro Oficina',
    itens: [
      ItemPedido(
        codauxiliar: '20953',
        codfab: '0441487F',
        desc: '0441487 - KIT DO AMORTECEDOR',
        m: '03',
        r: '03',
        p: '9',
        a: '308',
        qtd: 2,
      ),
      ItemPedido(
        codauxiliar: '32094',
        codfab: 'M8L206F',
        desc: 'M8L206 - COXIM',
        m: '03',
        r: '03',
        p: '10',
        a: '301',
        qtd: 3,
      ),
      ItemPedido(
        codauxiliar: '73374',
        codfab: 'LT90194F',
        desc: 'LT90194 - KIT AMORTECEDOR',
        m: '03',
        r: '03',
        p: '10',
        a: '322',
        qtd: 1,
      ),
    ],
  ),
  Pedido(
    id: '2100325',
    data: '2026-02-13',
    codFornecFrete: 1038,
    cliente: 'Dorika Auto Peças',
    itens: [
      ItemPedido(
        codauxiliar: '53333',
        codfab: 'K5T0412LD',
        desc: 'K5T0412 - BIELETA DIANTEIRA LD',
        m: '03',
        r: '04',
        p: '16',
        a: '301',
        qtd: 2,
      ),
      ItemPedido(
        codauxiliar: '53334',
        codfab: 'K5T0412LT',
        desc: 'K5T0412 - BIELETA DIANTEIRA LT',
        m: '03',
        r: '04',
        p: '17',
        a: '301',
        qtd: 2,
      ),
    ],
  ),
  Pedido(
    id: '2001200',
    data: '2026-02-12',
    codFornecFrete: 313,
    cliente: 'Auto Shopping das Peças',
    itens: [
      ItemPedido(
        codauxiliar: '76548',
        codfab: '30194F',
        desc: '30.194 - TENSIONADOR',
        m: '03',
        r: '12',
        p: '16',
        a: '201',
        qtd: 2,
      ),
      ItemPedido(
        codauxiliar: '47757',
        codfab: 'ARL1043F',
        desc: 'ARL1043 - FILTRO DE AR',
        m: '06',
        r: '01',
        p: '5',
        a: '108',
        qtd: 6,
      ),
    ],
  ),
  Pedido(
    id: '8895600',
    data: '2026-02-13',
    codFornecFrete: 313,
    cliente: 'JAP Auto Peças',
    itens: [
      ItemPedido(
        codauxiliar: '10348',
        codfab: 'TR6B10F',
        desc: 'TR6B-10 - VELA DE IGNIÇÃO',
        m: '06',
        r: '01',
        p: '5',
        a: '108',
        qtd: 4,
      ),
    ],
  ),
  Pedido(
    id: '3265880',
    data: '2026-02-12',
    codFornecFrete: 9999,
    cliente: 'Calçadão Auto Peças',
    itens: [
      ItemPedido(
        codauxiliar: '44758',
        codfab: '0462613F',
        desc: '0462613 - KIT DO AMORTECEDOR',
        m: '03',
        r: '03',
        p: '24',
        a: '301',
        qtd: 1,
      ),
    ],
  ),
];

class Modulo {
  const Modulo(this.chave, this.nome, this.implementado);
  final String chave;
  final String nome;
  final bool implementado;
}
