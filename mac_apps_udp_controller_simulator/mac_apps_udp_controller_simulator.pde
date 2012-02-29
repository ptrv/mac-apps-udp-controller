/*
  Author: Peter Vasil <p.vasil@gmail.com>
*/

import hypermedia.net.*;
import controlP5.*;

ControlP5 controlP5;
UDP udp;

float volumeValue = 0.0;
int volumeSendCount = 0;

String serverIp = "239.255.0.1";
//String serverIp = "localhost";
int serverPort = 5555;

Slider2D s;
float lastX = 50.0;
float lastY = 50.0;

String msgToSend = "";
void setup(){
  
  udp = new UDP( this, serverPort, serverIp );
  //udp.log( true );
  udp.listen( false );
  
  size(320,300);
  frameRate(25);
  
  controlP5 = new ControlP5(this);
  controlP5.addSlider("volume",0,100,50,40,50,10,100);
  //controlP5.addSlider("pinch",0,100,50,100,150,100,10);
  s = controlP5.addSlider2D("pinch",110,170,100,100);
  s.setArrayValue(new float[] {lastX, lastY});
  
  controlP5.addButton("one",0, 100,50,50,19);
  controlP5.addButton("two",0, 160,50,50,19);
  controlP5.addButton("three",0, 220,50,50,19);
  controlP5.addButton("four",0, 100,100,50,19);
  controlP5.addButton("five",0, 160,100,50,19);
  controlP5.addButton("nope",0, 220,100,50,19);
  
  controlP5.setMoveable(false);
}

void draw(){
  background(200);
  //udp.send(getTimestamp()+";NOPE");
}

void volume(float value){
  String message = getTimestamp()+";triangle;"+value;
  volumeValue = value;
  if(volumeSendCount > 2){
    udp.send( message );
    volumeSendCount = 0;
  } else {
    ++volumeSendCount;
  }
}

void one(){
  udp.send(getTimestamp()+";fingercount;1");
}

void two(){
  udp.send(getTimestamp()+";fingercount;2");
}

void three(){
  udp.send(getTimestamp()+";fingercount;3");
}

void four(){
  udp.send(getTimestamp()+";fingercount;4");
}

void five(){
  udp.send(getTimestamp()+";fingercount;5");
}
void nope(){
  udp.send(getTimestamp()+";NOPE");
}

int pinchCounter = 0;
float sumMoveX = 0.0;
float sumMoveY = 0.0;
void pinch(){
  ++pinchCounter;
  //if(pinchCounter > 3)
  {
    String dir = "";
    if(abs(sumMoveX) > abs(sumMoveY)){
      if(sumMoveX > 0)
        dir = "right";
       else
         dir = "left";
    }
    else if(abs(sumMoveX) < abs(sumMoveY))
    {
      if(sumMoveY > 0)
        dir = "down";
       else
         dir = "up";
    }
    else
    {
      dir = "NOPE";
    }
    println(dir);
//    udp.send(getTimestamp()+";pinch;"+s.arrayValue()[0]+";"+s.arrayValue()[1]+";0.0;"+dir);
    udp.send(getTimestamp()+";pinch;"+s.arrayValue()[0]+";"+s.arrayValue()[1]+";0.0");
    pinchCounter = 0;
    sumMoveX = sumMoveY = 0;
  }
  sumMoveX = sumMoveX + (s.arrayValue()[0] - lastX);
  sumMoveY = sumMoveY + (s.arrayValue()[1] - lastY);
  lastX = s.arrayValue()[0];
  lastY = s.arrayValue()[1];
}
String getTimestamp(){
  Date d = new Date();
  long now = d.getTime()/1000;
  return ""+now;
}
