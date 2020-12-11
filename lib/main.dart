import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';

void main() async {
  await GetStorage.init('test');
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
      home: MarketlistScreen(),
    );
  }
}

class MarketlistScreen extends StatefulWidget {
  MarketlistScreen({this.listName});
  final String listName;

  @override
  _MarketlistScreenState createState() => _MarketlistScreenState();
}

class _MarketlistScreenState extends State<MarketlistScreen> {
  final List<Product> products = [];
  final marketlist = Marketlist('test');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("title"),
      ),
      body: Center(
          child: ListView.builder(
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
      )),
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
  GetStorage box;
  DateTime date;
  List<Product> elements = [];

  Marketlist(String name) {
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
