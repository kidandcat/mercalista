import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

void main() async {
  runApp(GetMaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mercalista',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MarketlistScreen('test'),
    );
  }
}

class MarketlistScreen extends StatefulWidget {
  MarketlistScreen(this.listName);
  final String listName;

  @override
  _MarketlistScreenState createState() => _MarketlistScreenState(listName);
}

class _MarketlistScreenState extends State<MarketlistScreen> {
  Marketlist marketlist;

  /// listName is the key used to store the list on disk, it must be unique
  String listName;

  /// Receive listName as prop
  _MarketlistScreenState(this.listName) {
    marketlist = Marketlist(listName);
  }

  /// This is called only once when the Widget is added to the tree (useEffect)
  @override
  void initState() {
    super.initState();
    loadStorage();
  }

  /// GetStorage must be initialized per box or it will not load stored items
  void loadStorage() async {
    var ml = await Marketlist.load(listName);
    setState(() {
      marketlist = ml;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("title"),
      ),
      body: Center(
        child: marketlist != null
            ? ListView.builder(
                itemCount: marketlist.size(),
                itemBuilder: (context, index) => Container(
                  height: 60,
                  child: Row(
                    children: [
                      Image.network(marketlist.getProduct(index).image),
                      Flexible(child: Text(marketlist.getProduct(index).name)),
                      Text(marketlist.getProduct(index).price),
                    ],
                  ),
                ),
              )
            : CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          Get.snackbar("Loading", "getting product info");
          try {
            String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
                "red", "Cancelar", true, ScanMode.BARCODE);
            var productID = barcodeScanRes.substring(7, 12);
            var res = await http
                .get('https://tienda.mercadona.es/api/products/$productID');
            var j = jsonDecode(res.body);
            var p = Product.fromJson(j);
            setState(() {
              marketlist.addProduct(p);
            });
          } catch (e) {
            Get.defaultDialog(title: e.toString());
          }
        },
      ),
    );
  }
}

class Marketlist {
  String name;
  GetStorage box;
  DateTime date;
  List<Product> elements = [];

  static Future<Marketlist> load(String name) async {
    await GetStorage.init(name);
    return Marketlist(name);
  }

  Marketlist(String _name) {
    name = _name;
    box = GetStorage(name);
    date = box.read('date');
    var els = box.read<List<dynamic>>('elements');
    if (els != null) elements = els.map((p) => Product.fromJson(p)).toList();
  }

  Marketlist.fromJson(Map<String, dynamic> json)
      : date = json['date'],
        elements = json['elements'].map((p) => Product.fromJson(p));

  Map<String, dynamic> toJson() => {
        'date': date,
        'elements': elements,
      };

  void addProduct(Product p) {
    elements.add(p);
    box.write('elements', elements);
  }

  Product getProduct(int index) {
    return elements[index];
  }

  int size() {
    return elements.length;
  }
}

class Product {
  String name;
  String image;
  String price;
  int quantity = 1;
  Product({this.name, this.image, this.price});
  Product.fromJson(Map<String, dynamic> json)
      : name = json['display_name'],
        image = json['thumbnail'],
        price = json['price_instructions']['unit_price'];
  Map<String, dynamic> toJson() => {
        'display_name': name,
        'thumbnail': image,
        'price_instructions': {
          'unit_price': price,
        }
      };
}
