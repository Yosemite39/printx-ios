
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const PrintXApp());

class Product {
  final String name;
  final int price;
  final String section;
  final String unit;
  final int netPrice;
  int qty;
  Product(this.name, this.price, this.section, this.unit, this.netPrice, {this.qty = 0});
  int get box => 0;
  int get bal => qty ~/ 100;
  int get slof => (qty % 100) ~/ 10;
  int get pak => qty % 10;
  int get totPak => qty;
  int get effectivePrice => netPrice > 0 ? netPrice : price;
  int get subtotal => qty * effectivePrice;
  int get baseSubtotal => qty * price;
}

class PrintXApp extends StatelessWidget {
  const PrintXApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PrintX iOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: const Color(0xff080706),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xff33aaff),
          selectionColor: Color(0x6633aaff),
          selectionHandleColor: Color(0xff33aaff),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff17110d),
          hintStyle: const TextStyle(color: Color(0xffb9aa9b)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff4a3324))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xff33aaff), width: 2)),
        ),
      ),
      home: const PrintXHome(),
    );
  }
}

class PrintXHome extends StatefulWidget {
  const PrintXHome({super.key});
  @override
  State<PrintXHome> createState() => _PrintXHomeState();
}

class _PrintXHomeState extends State<PrintXHome> {
  final salesman = TextEditingController();
  final customer = TextEditingController();
  final note = TextEditingController();
  final search = TextEditingController();
  String activeSection = 'ALL';
  bool showPreview = true;
  final List<Product> products = _catalog.map((m) => Product(m['name'] as String, m['price'] as int, m['section'] as String, m['unit'] as String, m['netPrice'] as int)).toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      salesman.text = p.getString('salesman') ?? '';
      customer.text = p.getString('customer') ?? '';
      note.text = p.getString('note') ?? '';
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('salesman', salesman.text);
    await p.setString('customer', customer.text);
    await p.setString('note', note.text);
  }

  List<Product> get filtered => products.where((p) {
    if (activeSection != 'ALL' && p.section != activeSection) return false;
    final q = search.text.toLowerCase().trim();
    return q.isEmpty || p.name.toLowerCase().contains(q);
  }).toList();

  int sectionTotal(String sec) => products.where((p) => p.section == sec).fold(0, (a, p) => a + p.subtotal);
  int sectionBaseTotal(String sec) => products.where((p) => p.section == sec).fold(0, (a, p) => a + p.baseSubtotal);
  int templateTotal(String sec) => sec == 'V1' ? sectionTotal('V1') + sectionTotal('SFP') : sectionTotal(sec);
  int get total => products.fold(0, (a, p) => a + p.subtotal);

  @override
  Widget build(BuildContext context) {
    final receipt = receiptText();
    return Scaffold(
      appBar: AppBar(title: const Text('PrintX iOS'), backgroundColor: const Color(0xff100c09)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('PrintX iOS Port', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xffff8a24))),
          const SizedBox(height: 12),
          _input(salesman, 'Salesman'),
          _input(customer, 'Pelanggan tiap transaksi'),
          _input(note, 'NO. NOTA PENJUALAN'),
          const SizedBox(height: 12),
          _input(search, 'Cari produk...', onChanged: (_) => setState(() {})),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['ALL','V1','V2','ABC','Korek','SFP'].map((s) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s), selected: activeSection == s, onSelected: (_) => setState(() => activeSection = s)))).toList())),
          const SizedBox(height: 12),
          Row(children: ['V1','V2','ABC','Korek'].map((s) => Expanded(child: Card(color: templateTotal(s) > 0 ? const Color(0xff2a1810) : const Color(0xff100c09), child: Padding(padding: const EdgeInsets.all(10), child: Text('$s\nRp ${money(templateTotal(s))}', textAlign: TextAlign.center))))).toList()),
          const SizedBox(height: 12),
          ...filtered.map(_productTile),
          const SizedBox(height: 12),
          Text('Grand Total: ${money(total)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xffff8a24))),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: () { Clipboard.setData(ClipboardData(text: receipt)); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Raw receipt copied'))); }, child: const Text('Copy Raw Text'))),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton(onPressed: () => setState(() => showPreview = !showPreview), child: const Text('Preview'))),
          ]),
          if (showPreview) Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(14), color: Colors.white, child: SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(receipt, style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.black)))),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {ValueChanged<String>? onChanged}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(controller: c, onChanged: (v) { _save(); onChanged?.call(v); setState(() {}); }, decoration: InputDecoration(hintText: hint)),
  );

  Widget _productTile(Product p) => Card(
    color: const Color(0xff17110d),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('[${p.section}] ${p.name}\nHarga/${p.unit} ${money(p.price)}${p.netPrice > 0 ? ' → Net ${money(p.netPrice)}' : ''} | Qty ${p.qty}', style: const TextStyle(fontFamily: 'monospace')),
        Row(children: [
          IconButton(onPressed: () => setState(() { if (p.qty > 0) p.qty--; }), icon: const Icon(Icons.remove_circle_outline)),
          IconButton(onPressed: () => setState(() => p.qty++), icon: const Icon(Icons.add_circle_outline)),
          Expanded(child: TextField(key: ValueKey(p.name), keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: 'Qty'), onChanged: (v) => setState(() => p.qty = int.tryParse(v) ?? p.qty))),
        ])
      ]),
    ),
  );

  String receiptText() {
    final sections = ['V1','V2','ABC','Korek'].where((s) => templateTotal(s) > 0).toList();
    if (sections.isEmpty) return receiptV1('V1');
    final parts = <String>[];
    for (final s in sections) {
      if (s == 'V1') parts.add(receiptV1(s));
      if (s == 'V2') parts.add(receiptV2(s));
      if (s == 'ABC') parts.add(receiptPanamas(s));
      if (s == 'Korek') parts.add(receiptKorek(s));
    }
    return parts.join('\n\n==================== POTONG NOTA ====================\n\n');
  }

  String receiptV1(String sec) {
    final lines = <String>[];
    lines.addAll([center('PT HM SAMPOERNA Tbk. - Sales DPC RE Cilacap'), center('Jln Raya Jeruk Legi Rt.03/05, CILACAP'), '', '', center('*** PENJUALAN ***'), '']);
    field(lines, 'Salesman', salesman.text); field(lines, 'Pelanggan', customer.text); field(lines, 'Tanggal', englishDate()); field(lines, 'NO. NOTA PENJUALAN', note.text);
    lines.addAll(['', '', fmt('%-16s%3s%4s%5s%4s%7s%8s%8s', ['PROD','Box','Bal','Slof','Pak','TotPak','Harga','SubT']), dash(), '']);
    for (final p in products.where((p) => p.totPak > 0 && (p.section == sec || (sec == 'V1' && p.section == 'SFP')))) { lines.add(cut(p.name)); lines.add(fmt('%16s%3d%4d%5d%4d%7d%8s%8s', ['', p.box, p.bal, p.slof, p.pak, p.totPak, money(p.price), money(p.subtotal)])); lines.add(''); }
    commonTotals(lines, sec, 'UANG TUNAI'); lines.add('PENERIMA                              PENJUAL'); return lines.join('\n');
  }

  String receiptV2(String sec) {
    final lines = <String>[];
    lines.addAll([center('ESA SAMPOERNA CENTER Lt.5'), center('Jl. Dr. Ir. H. Soekarno 198'), center('Surabaya 60117 - Jawa Timur'), center('62 31 2979216'), '', center('*** PENJUALAN ***'), '']);
    field(lines, 'Pengantar', salesman.text); field(lines, 'Pelanggan', customer.text); field(lines, 'Kode Referensi', sclXqmCode()); field(lines, 'Kode Referensi Baru', customerCodeOnly()); field(lines, 'Tanggal', englishDate()); field(lines, 'NO. NOTA PENJUALAN', sclNotaNumber());
    lines.addAll(['', fmt('%-16s%3s%4s%5s%4s%7s%8s%8s', ['PROD','Box','Bal','Slof','Pak','TotPak','Harga','SubT']), dash(), '']);
    for (final p in products.where((p) => p.totPak > 0 && p.section == sec)) { lines.add(cut(p.name)); lines.add(fmt('%16s%3d%4d%5d%4d%7d%8s%8s', ['', p.box, p.bal, p.slof, p.pak, p.totPak, money(p.price), money(p.subtotal)])); lines.add(''); }
    commonTotals(lines, sec, 'UANG TUNAI BV1'); lines.add('PENERIMA                             PENGANTAR'); return lines.join('\n');
  }

  String receiptPanamas(String sec) {
    final lines = <String>[]; final sub = sectionBaseTotal(sec), grand = sectionTotal(sec), ppn = grand - sub;
    lines.addAll([center('PT. Perusahaan Dagang & Industri Panamas - Sales DPC'), center('RE Cilacap'), center('Jln Raya Jeruk Legi Rt.03/05, CILACAP'), center('(031) 8431699'), '', center('*** PENJUALAN ***'), '']);
    field(lines, 'Salesman', salesman.text); field(lines, 'Pelanggan', customer.text); field(lines, 'Tanggal', englishDate()); field(lines, 'NO. NOTA PENJUALAN', note.text);
    lines.addAll(['', fmt('%-12s%4s %-4s %8s %6s %8s %8s', ['PROD','Qty','Unit','Harga','Disc','HrgNet','Total']), dash(), '']);
    for (final p in products.where((p) => p.totPak > 0 && p.section == sec)) { lines.add(cut(p.name)); lines.add(fmt('%12s%4d %-4s %8s %6s %8s %8s', ['', p.totPak, p.unit, money(p.price), '0', money(p.effectivePrice), money(p.subtotal)])); lines.add(''); }
    lines.addAll([twoCol('Sub Total', money(sub)), '', twoCol('Diskon','0'), '', twoCol('PPN', money(ppn)), '', twoCol('Total Bayar', money(grand)), '', '']); payment(lines, grand, 'UANG TUNAI'); terms(lines); lines.add('YANG MENERIMA                    YANG MENYERAHKAN'); return lines.join('\n');
  }

  String receiptKorek(String sec) {
    final lines = <String>[]; final sub = sectionBaseTotal(sec), grand = sectionTotal(sec), ppn = grand - sub;
    lines.addAll([center('PT. SRC Indonesia Sembilan - Sales DPC RE Cilacap'), center('Jln Raya Jeruk Legi Rt.03/05 , CILACAP'), center('+62 804-1000-234'), '', center('*** PENJUALAN ***'), '']);
    field(lines, 'Salesman', salesman.text); field(lines, 'Pelanggan', customer.text); field(lines, 'Tanggal', englishDate()); field(lines, 'NO. NOTA PENJUALAN', note.text);
    lines.addAll(['', fmt('%-12s%4s %-4s %8s %6s %8s %8s', ['PROD','Qty','Unit','Harga','Disc','HrgNet','Total']), dash(), '']);
    for (final p in products.where((p) => p.totPak > 0 && p.section == sec)) { lines.add(cut(p.name)); lines.add(fmt('%12s%4d %-4s %8s %6s %8s %8s', ['', p.totPak, p.unit, money(p.price), '0', money(p.effectivePrice), money(p.subtotal)])); lines.add(''); }
    lines.addAll([twoCol('Sub Total', money(sub)), '', twoCol('Diskon','0'), '', twoCol('PPN', money(ppn)), '', twoCol('Total Bayar', money(grand)), '']); payment(lines, grand, 'UANG TUNAI'); terms(lines, extra: true); lines.add('YANG MENERIMA                    YANG MENYERAHKAN'); return lines.join('\n');
  }

  void commonTotals(List<String> lines, String sec, String payLabel) { final t = templateTotal(sec); lines.addAll([twoCol('Grand Total', money(t)), '', '']); payment(lines, t, payLabel); lines.addAll(['', twoCol('Grand Total', money(t)), '', twoCol('Total Bayar', money(t)), '', '']); terms(lines); }
  void payment(List<String> lines, int total, String label) => lines.addAll(['Rincian Pembayaran', 'Tipe/Ref No        CNF Number   Due Date     Subtotal', dash(), '', twoCol(label, money(total)), '', '']);
  void terms(List<String> lines, {bool extra = false}) { lines.add(center('*** Syarat dan Ketentuan Berlaku ***')); lines.add(''); lines.add(center('Mohon untuk selalu memastikan jumlah barang yang diterima', w: 58)); lines.add(center('sesuai dengan pesanan dan nilai uang yang dibayarkan', w: 58)); if (extra) lines.add(center('Barang yang sudah dibeli tidak dapat dikembalikan', w: 58)); lines.addAll(['', '', 'Tanda Tangan', '', '', '', '', '', '', '', '']); }

  void field(List<String> lines, String k, String v) { lines.add(cut('${k.padRight(18)}: $v')); lines.add(''); }
  String customerCodeOnly() { final c = customer.text; final i = c.indexOf('/'); return i > 0 ? c.substring(0, i).trim() : c; }
  String sclXqmCode() => 'XQM${((note.text + customer.text).hashCode.abs() % 10000000).toString().padLeft(7, '0')}';
  String sclNotaNumber() { final n = note.text.trim(); final i = n.indexOf('PWL'); if (i >= 0) return 'B${n.substring(i)}'; final c = customerCodeOnly(); return c.startsWith('PWL') ? 'B$c' : 'BPWL${c.replaceAll(RegExp(r'[^0-9]'), '')}'; }
  String englishDate() => DateTime.now().toString().substring(0,16).replaceFirst('T',' ');
}

const int cw = 56;
String money(int v) => v.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
String cut(String s, [int w = cw]) => s.length <= w ? s : s.substring(0, w);
String center(String s, {int w = cw}) { s = cut(s, w); return ' ' * ((w - s.length) ~/ 2).clamp(0, w) + s; }
String dash() => '_' * cw;
String twoCol(String left, String right, {int w = cw}) { w = (w - 4).clamp(42, 200); final lw = (w - right.length - 2).clamp(0, w); final l = cut(left, lw); return l + ' ' * (w - right.length - l.length).clamp(2, w) + right; }
String fmt(String pattern, List<dynamic> args) {
  // Tiny formatter for fixed-width receipt rows used by this app.
  var i = 0;
  return pattern.replaceAllMapped(RegExp(r'%(-?)(\d*)s|%(-?)(\d*)d'), (m) {
    final left = (m.group(1) ?? m.group(3) ?? '') == '-';
    final widthText = (m.group(2) != null && m.group(2)!.isNotEmpty) ? m.group(2)! : (m.group(4) ?? '0');
    final width = int.tryParse(widthText) ?? 0;
    final v = '${args[i++]}';
    if (width <= v.length) return v;
    return left ? v.padRight(width) : v.padLeft(width);
  });
}

final List<Map<String, Object>> _catalog = [
  {
    "name": "Avolution Mtl 20 47500 2026",
    "price": 43000,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Avolution 20 47500 2026",
    "price": 43000,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Magnum Kretek (Refine) 12 18675 2026",
    "price": 16400,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS 6Plus6 12 26075 2026",
    "price": 19250,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Super Premium (Soft Pack) 12 26075 2026",
    "price": 13450,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Super Premium 12 LEP Maestro 26075 2026",
    "price": 18400,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Ice Burst 20 49900 2026",
    "price": 51850,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna A Splash Royal 16 38000 2026",
    "price": 30000,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Gold 20 LEP Sustainability 49900",
    "price": 40700,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Red 20 LEP Sustainability 49900",
    "price": 40700,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Ice Burst 20 LEP Sustainability",
    "price": 40700,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna A Mild Mtl Burst 16 38000 2026",
    "price": 35150,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Filter Black Motion 20 47500 2026",
    "price": 37900,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Magnum Kretek Coklat 12 18675 2026",
    "price": 16400,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Magnum Kretek 12 18675 2026",
    "price": 16400,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna A Mild 16 LEP Vintage 38000 2026",
    "price": 32600,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna A Mild 12 28500 2026",
    "price": 25150,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna A Mild 16 38000 2026",
    "price": 35150,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Kretek Prima 12 18675 2026",
    "price": 14800,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Hijau Legit Nira 12 18675 2026",
    "price": 13300,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Hijau Legit Amerta 12 18675 2026",
    "price": 13300,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Hijau 10Plus2 12 18675 2026",
    "price": 15450,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Hijau Legit Sada 12 18675 2026",
    "price": 13300,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Kretek Prima (Soft Pack) 12 18675 2026",
    "price": 13450,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Gold 20 49900 2026",
    "price": 40700,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Red 20 49900 2026",
    "price": 40700,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Crafted Origin With Wrap 12 11950 2026",
    "price": 11150,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Filter Black 12 28500 2026",
    "price": 23600,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Filter Black 16 38000 2026",
    "price": 31000,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Filter Black 20 47500 2026",
    "price": 37900,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna A Splash Tropical 16 38000 2026",
    "price": 20800,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Sampoerna Hijau 12 18675 2026",
    "price": 13300,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Super Premium 12 26075 2026",
    "price": 13450,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Super Premium 16 34750 2026",
    "price": 25700,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Magnum 12 LEP Price Dynamics 28500 2026",
    "price": 26250,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Magnum 12 28500 2026",
    "price": 26250,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "DSS Kretek 12 26075 2026",
    "price": 19250,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Marlboro Crafted 12 11950 2026",
    "price": 11150,
    "section": "V1",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Aspro Inter HT 16 23775 2026",
    "price": 22400,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Ares Bold HT 12 17825 2026",
    "price": 15950,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Balai Emas HT 12 17825 2026",
    "price": 15300,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Lodjie Ijo SKT 12 10325 2026",
    "price": 7900,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Nian SKT 16 13775 2026",
    "price": 9350,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Serasa SKT 16 13775 2026",
    "price": 8950,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Twizz Prime Royal LT 16 23775 2026",
    "price": 22500,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Twizz Prime Tropical LT 16 23775 2026",
    "price": 22500,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Twizz Prime LT 16 23775 2026",
    "price": 21350,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Twizz Royal Crush LT 12 17825 2026",
    "price": 18750,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Twizz Royal Crush LT 16 23775 2026",
    "price": 24700,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "Twizz Yellow Crush LT 16 23775 2026",
    "price": 24700,
    "section": "V2",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "ABC Kecap MNS PCH 250G",
    "price": 6508,
    "section": "ABC",
    "unit": "Pcs",
    "netPrice": 7223
  },
  {
    "name": "ABC Sambal Asli RCG 8G",
    "price": 251,
    "section": "ABC",
    "unit": "Pcs",
    "netPrice": 279
  },
  {
    "name": "ABC Sambal Terasi RCG 18G",
    "price": 11228,
    "section": "ABC",
    "unit": "Pac",
    "netPrice": 12463
  },
  {
    "name": "ABC Sambal Extra Pedas BTL 130ML",
    "price": 5680,
    "section": "ABC",
    "unit": "Pcs",
    "netPrice": 6305
  },
  {
    "name": "Korek Api Cricket Fusion",
    "price": 3154,
    "section": "Korek",
    "unit": "Pcs",
    "netPrice": 3501
  },
  {
    "name": "Korek Api Cricket Intense",
    "price": 3154,
    "section": "Korek",
    "unit": "Pcs",
    "netPrice": 3501
  },
  {
    "name": "Korek Api Cricket Flint Original",
    "price": 3154,
    "section": "Korek",
    "unit": "Pcs",
    "netPrice": 3501
  },
  {
    "name": "VEEVA ONE GRAPE 3.5% 1ML 42000 2026",
    "price": 42000,
    "section": "SFP",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "VEEVA ONE MANGO 3.5% 1ML 42000 2026",
    "price": 42000,
    "section": "SFP",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "VEEVA ONE RED MELON 3.5% 1ML MNT 42000 2026",
    "price": 42000,
    "section": "SFP",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "VEEVA ONE LEMON TEA 3.5% 1ML 42000 2026",
    "price": 42000,
    "section": "SFP",
    "unit": "Pak",
    "netPrice": 0
  },
  {
    "name": "VEEVA ONE STRVW CLOVE 3.5% 1ML 42000 2026",
    "price": 42000,
    "section": "SFP",
    "unit": "Pak",
    "netPrice": 0
  }
];
