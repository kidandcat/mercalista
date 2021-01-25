import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:get_storage/get_storage.dart';
import 'package:camera/camera.dart';
import 'package:image/image.dart' as imgLib;

List<CameraDescription> cameras;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
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
  CameraController controller;
  static const goScanner =
      const MethodChannel('com.example.mercalista/goscanner');

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
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
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
        title: Text(listName),
      ),
      body: Center(
        child: Column(
          children: [
            marketlist != null
                ? Expanded(
                    child: ListView.builder(
                      itemCount: marketlist.size(),
                      itemBuilder: (context, index) => Container(
                        height: 60,
                        child: Row(
                          children: [
                            if (marketlist.getProduct(index).image != null)
                              Image.network(marketlist.getProduct(index).image),
                            if (marketlist.getProduct(index).name != null)
                              Flexible(
                                  child:
                                      Text(marketlist.getProduct(index).name)),
                            Text(marketlist.getProduct(index).price),
                            // TODO remove example and use drag and drop
                            ElevatedButton(
                              child: Text('Swap down'),
                              onPressed: () {
                                setState(() {
                                  marketlist.swapProducts(index, index + 1);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : CircularProgressIndicator(),
            (controller.value.isInitialized)
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: CameraPreview(controller),
                  )
                : CircularProgressIndicator(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            var counter = 3;
            var found = false;
            controller.startImageStream((CameraImage img) async {
              counter--;
              if (counter < 0 || found) {
                try {
                  await controller.stopImageStream();
                } catch (e) {}
              }
              if (counter < 0 || found) return;
              var data = await Conversor.convertYUV420toImage(img);
              var result = (await goScanner.invokeMethod('scan', data));
              if (!isNumeric(result)) {
                print('----------------- Gor error $result');
                return; // got Go error
              } else {
                found = true;
                print('----------------- Got number $result');
                var res = await http.get(
                    'https://tienda.mercadona.es/api/products/${result.substring(7, 12)}');
                var j = jsonDecode(res.body);
                var p = Product.fromJson(j);
                setState(() {
                  marketlist.addProduct(p);
                });
              }
            });

            // TODO desodorante not working, investigate barcode
            // String barcodeScanRes = await FlutterBarcodeScanner.scanBarcode(
            //     "red", "Cancelar", true, ScanMode.BARCODE);
            // var productID = barcodeScanRes.substring(7, 12);

          } catch (e) {
            print('Exception');
            Get.defaultDialog(title: 'Exception', middleText: e.toString());
          }
        },
      ),
    );
  }
}

bool isNumeric(String s) {
  if (s == null) {
    return false;
  }
  try {
    return double.parse(s) != null;
  } catch (e) {
    return false;
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
    // TODO delete everything for debugging purposes
    // box.erase();
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

  void deleteProduct(int index) {
    elements.removeAt(index);
    box.write('elements', elements);
  }

  void swapProducts(int a, b) {
    var aProduct = elements[a];
    var bProduct = elements[b];
    elements[a] = bProduct;
    elements[b] = aProduct;
    box.write('elements', elements);
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
        price = (json['price_instructions'] != null)
            ? json['price_instructions']['unit_price']
            : 'Not found';
  Map<String, dynamic> toJson() => {
        'display_name': name,
        'thumbnail': image,
        'price_instructions': {
          'unit_price': price,
        }
      };
}

class Conversor {
  static Future<Uint8List> convertYUV420toImage(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      // imgLib -> Image package from https://pub.dartlang.org/packages/image
      var img = imgLib.Image(width, height); // Create Image buffer

      // Fill image buffer with plane[0] from YUV420_888
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final pixelColor = image.planes[0].bytes[y * width + x];
          // color: 0x FF  FF  FF  FF
          //           A   B   G   R
          // Calculate pixel color
          img.data[y * width + x] = (0xFF << 24) |
              (pixelColor << 16) |
              (pixelColor << 8) |
              pixelColor;
        }
      }
      List<int> png = imgLib.encodePng(img);
      return png;
    } catch (e) {
      print(">>>>>>>>>>>> ERROR:" + e.toString());
    }
    return null;
  }
}
