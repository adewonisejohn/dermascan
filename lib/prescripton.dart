import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dermascan/main.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:io';
import 'package:tflite/tflite.dart';
import 'package:image/image.dart' as img;
import 'package:url_launcher/url_launcher.dart';



class prescription extends StatefulWidget {

  prescription({required this.file_path});

  var file_path;
  @override
  State<prescription> createState() => _prescriptionState();
}

class _prescriptionState extends State<prescription> {
  late GoogleMapController mapController;
  var predicted_data;
  var data;
  bool is_predicting=false;
  var output ;
  var prediction_index=0;

  static const LatLng currentLocation = LatLng(9.0820,8.6753);
  void load_data() async{
    var index=this.prediction_index.toString();
    print('about to load data');
    final String response = await rootBundle.loadString('assets/prescription.json');
    final temp_data = await json.decode(response);
    setState((){
      data = temp_data["data"][this.prediction_index];
    });
    print("predicted index is ${this.prediction_index}--------------------------");
    print(data["name"]);

    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    print("----------------------------------------------------------");
    print(position);

  }

  void print_data(bool share) async{
    final doc = pw.Document();

    doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Center(
            child:pw.Column(
              children:[
                pw.Text(
                  "Name : ${data["name"]}",
                  style:pw.TextStyle(
                    fontSize:50
                  )
                ),
                pw.SizedBox(
                    height:50
                ),
                pw.Text(
                  "Description : ${data["overview"]}",
                  style:pw.TextStyle(
                    fontSize:25
                  )
                ),
                pw.SizedBox(
                    height:50
                ),
                pw.Text(
                  "Symptoms : ${data["symptoms"]}",
                    style:pw.TextStyle(
                        fontSize:25
                    )
                ),
                pw.SizedBox(
                  height:50
                ),
                pw.Text(
                  "${data["treatment"]}",
                    style:pw.TextStyle(
                        fontSize:25
                    )
                )
              ]
            )
          ); // Center
        })); // Page
    if(share == true){
      await Printing.sharePdf(bytes: await doc.save(), filename: 'scan-result.pdf');
    }else{
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
    }
  }
  Future<void>_initTensorflow()async {
    String? res = await Tflite.loadModel(
        model: "assets/model.tflite",
        labels: "assets/labels.txt",
        numThreads: 1, // defaults to 1
        isAsset: true, // defaults to true, set to false to load resources outside assets
        useGpuDelegate: false // defaults to false, set to true to use GPU delegate
    );
    print("result after loading model ${res}");
  }
  Future<void> predict(var filepath) async{
    setState(() {
      this.is_predicting=true;
    });
    print('about to predict second model');

    final image = img.decodeImage(File(filepath).readAsBytesSync());

    final resizedImage = img.copyResize(image! , width:224, height:224);
    File(filepath).writeAsBytesSync(img.encodePng(resizedImage));

    print(filepath);

    var recognitions;
    recognitions = await Tflite.runModelOnImage(
        path:filepath,   // required
        imageMean: 0.0,   // defaults to 117.0
        imageStd: 255.0,  // defaults to 1.0
        numResults: 1,    // defaults to 5
        threshold: 0.2,   // defaults to 0.1
        asynch: true      // defaults to true
    );
    setState(() {
      output=recognitions;
    });

    print("result of recognition is ------------------------");
    print(output[0]["index"]);
    print(recognitions);
    print("--------------------------------------------------");
    setState(() {
      this.is_predicting=false;
      this.prediction_index=output[0]["index"];
      load_data();
    });

  }

  Future<void>_find_dermatologist()async{
    final link="www.google.com/maps/search/dermatologist+around+me";
    final url ='https:$link';
    if(await canLaunchUrl(Uri.parse(url))){
      launchUrl(
        Uri.parse(url),
        mode:LaunchMode.externalNonBrowserApplication,

      );
    }
  }



  @override
  void initState() {
    _initTensorflow();
    predict(widget.file_path);
    // TODO: implement initState
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar:BottomAppBar(
        child:Container(
          height:MediaQuery.of(context).size.height*0.11,
          padding:EdgeInsets.only(left:20,right:20),
          decoration:BoxDecoration(
            color:Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.4),
                spreadRadius: 3,
                blurRadius: 3,
                offset: Offset(0, 3), // changes position of shadow
              ),
            ],
          ),
          child:Row(
            mainAxisAlignment:MainAxisAlignment.spaceBetween,
            crossAxisAlignment:CrossAxisAlignment.center,
            children: [
              Column(
                mainAxisAlignment:MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap:(){
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => MyHomePage(title:"DermaScan")),
                      );
                    },
                      child: Icon((Icons.camera_alt_outlined))
                  ),
                  SizedBox(height:7,),
                  Text("New")
                ],
              ),
              GestureDetector(
                onTap:(){
                  print_data(true);
                },
                child: Column(
                  mainAxisAlignment:MainAxisAlignment.center,
                  children: [
                    Icon((Icons.ios_share_outlined)),
                    SizedBox(height:7,),
                    Text("Share")
                  ],
                ),
              ),
              GestureDetector(
                onTap:(){
                  _find_dermatologist();
                },
                child: Container(
                  width:MediaQuery.of(context).size.width*0.65,
                  height:50,
                  padding:EdgeInsets.only(left:10,right:10),
                  decoration:BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: [
                          Colors.green,
                          Colors.green,
                        ],
                      ),
                      ///color:Colors.black,
                      borderRadius:BorderRadius.circular(50)
                  ),
                  child:Row(
                    mainAxisAlignment:MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_outlined,color:Colors.white,size:27),
                      SizedBox(width:10,),
                      Text(
                          "Find a Dermatologist",
                        style: GoogleFonts.lato(
                          fontSize:17,
                          textStyle: TextStyle(color: Colors.white,fontWeight:FontWeight.w600),
                        ),
                      )
                    ],
                  ),
                ),
              )
            ],
          ),
        )
      ),
      body:is_predicting==false?Container(
        color:Colors.white,
        child:Column(
          children: [
            Container(
              color:Colors.white,
              height:MediaQuery.of(context).size.height*0.12,
              padding:EdgeInsets.only(left:20,right:20,top:50),
              child: Row(
                mainAxisAlignment:MainAxisAlignment.spaceBetween,
                crossAxisAlignment:CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap:(){
                      Navigator.pop(context);

                  }, child: Icon(Icons.arrow_back_ios_new_outlined,size:25)
                  ),
                  GestureDetector(
                    onTap:(){
                      print("about to print file");
                      print_data(false);
                    },
                      child: Icon(Icons.print_outlined,size:25)
                  )
                ],
              ),
            ),
            Container(
              padding:EdgeInsets.only(left:20,right:20),
              child: Align(
                alignment:Alignment.topLeft,
                child: Text(
                  data["name"],
                  style: GoogleFonts.lato(
                    fontSize:23,
                    textStyle: TextStyle(color: Colors.black, letterSpacing: .5,fontWeight:FontWeight.w900),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Container(
                padding:EdgeInsets.only(left:20,right:20),
                color:Colors.white,
                child:SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children: [
                      SizedBox(height:10,),
                      Align(
                        alignment:Alignment.topLeft,
                        child:Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.description_outlined,color:Colors.blue,),
                                Text(
                                  'Description',
                                  style:GoogleFonts.lato(
                                    fontSize:17,
                                    textStyle:TextStyle(color:Colors.black,letterSpacing: .5,fontWeight:FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height:10,),
                            Text(
                                data["overview"],
                              style: GoogleFonts.montserrat(
                                fontSize:15,
                                textStyle: TextStyle(color: Colors.black54, letterSpacing: .5,fontWeight:FontWeight.w500),
                              ),
                            ),

                          ],
                        ),
                      ),
                      Container(
                          height:10,color:Colors.grey.shade300,
                        margin:EdgeInsets.only(top:5,bottom:5),
                      ),
                      Align(
                        alignment:Alignment.topLeft,
                        child:Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.coronavirus_outlined,color:Colors.green),
                                Text(
                                  'Symptoms',
                                  style:GoogleFonts.lato(
                                    fontSize:17,
                                    textStyle:TextStyle(color:Colors.black,letterSpacing: .5,fontWeight:FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height:10,),
                            Text(
                              data["symptoms"],
                              style: GoogleFonts.montserrat(
                                fontSize:15,
                                textStyle: TextStyle(color: Colors.black54, letterSpacing: .5,fontWeight:FontWeight.w500),
                              ),
                            ),

                          ],
                        ),
                      ),
                      Container(
                        height:10,color:Colors.grey.shade300,
                        margin:EdgeInsets.only(top:5,bottom:5),
                      ),
                      Align(
                        alignment:Alignment.topLeft,
                        child:Column(
                          children: [
                            Row(
                              children: [
                                Icon(Icons.local_hospital,color:Colors.red,),
                                Text(
                                  'Treatment',
                                  style:GoogleFonts.lato(
                                    fontSize:17,
                                    textStyle:TextStyle(color:Colors.black,letterSpacing: .5,fontWeight:FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height:10,),
                            Text(
                              data["treatment"],
                              style: GoogleFonts.montserrat(
                                fontSize:15,
                                textStyle: TextStyle(color: Colors.black54, letterSpacing: .5,fontWeight:FontWeight.w500),
                              ),
                            ),

                          ],
                        ),
                      )
                    ],
                  ),
                ),
              ),
            )

          ],
        ),
      ):Container(
        child:Center(
          child:CircularProgressIndicator(
            color:Colors.greenAccent,
          ),
        ),
      ),
    );
  }
}


