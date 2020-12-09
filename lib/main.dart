import 'dart:convert';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_scanner/flutter_barcode_scanner.dart';
import 'package:http/http.dart' as http;

void main() {
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
      home: Home(),
    );
  }
}

class Home extends StatefulWidget {
  @override
  _HomeState createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Product> products = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("title"),
      ),
      body: Center(
          child: ListView.builder(
        itemCount: products.length,
        itemBuilder: (context, index) => Container(
          height: 60,
          child: Row(
            children: [
              Image.network(products[index].image),
              Flexible(child: Text(products[index].name)),
              Text(products[index].price),
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
              products.add(p);
            });
          } catch (e) {
            Get.defaultDialog(title: e.toString());
          }
        },
      ),
    );
  }
}

class Product {
  String name;
  String image;
  String price;
  Product({this.name, this.image, this.price});
  Product.fromJson(Map<String, dynamic> json)
      : name = json['display_name'],
        image = json['thumbnail'],
        price = json['price_instructions']['unit_price'];
}
