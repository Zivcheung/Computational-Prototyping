//Creator:Tianzhu Zhang
//In the Computational Prototyping course with Pierre Proske

//The project utilize the gray scott reaction diffusion fomular and PixelFlow library to accelerate the render spead.
/*reference projects:
  In depth tutorial on Reaction-Diffusion Tutorial by Karl Sims_________http://www.karlsims.com/rd.html
  Reaction Diffusion Algorithm in p5.js -------DANIEL SHIFFMAN
  Thread of how to use 32bits acceleration______________https://forum.processing.org/two/discussion/22385/reaction-diffusion-using-glsl-works-different-from-normal
  Website of Pixel flow library: http://thomasdiewald.com/
  Ignazio Lucenti's Processing: Gray-Scott Reaction Diffusion_______________https://vimeo.com/233477384
*/

//JOGL class 
import com.jogamp.opengl.GL2;

//pixelFlow classes
import com.thomasdiewald.pixelflow.java.DwPixelFlow;
import com.thomasdiewald.pixelflow.java.dwgl.DwGLSLProgram;
import com.thomasdiewald.pixelflow.java.dwgl.DwGLTexture;
import com.thomasdiewald.pixelflow.java.imageprocessing.filter.DwFilter;//static filter;

//GUI library
import controlP5.*;

//processing class;
import processing.core.PApplet;
import processing.opengl.PGraphics2D;



//classes
ControlP5 p5;
Accordion accordion;
Accordion accordion_color;
//images
Back_pic randerImages;//class to set background image for rendering 
//images change the parameter of gray scott diffusion
Back_pic backImages;

DwPixelFlow context;
PGraphics2D canvas;
//PShader diffusion;//Processing's shader class
//PShader coloring;
DwGLSLProgram grayScott_shader;
DwGLSLProgram render_shader;

//grayScott texture shader
DwGLTexture dwTexture;
//background texture shader
DwGLTexture back_tex;
//
DwGLTexture back_painting;
//saving class
Save_file sv;
//frame buffer
ArrayList<PImage> buffers;
boolean saveBuffer;
PGraphics output;

//coefficient Linked with ControlP5
float da;//coefficient 
float db;//coefficient 
float f;//feed rate 
float k;//kill rate
float dt;//delta time
int iteration;

//render variables
ColorPicker cp;
int render_mode=0;
int filter_mode=0;
int render_number;//number of based image to render
int image_number;//number of based image of filter


boolean boolean_start=false;
boolean boolean_controller=true;
boolean haveBuffer=false;
boolean firstTime=true;
int welcomeTime=1;
  
void setup(){
  
  fullScreen(P2D);
  //size(800,800,P2D);
  
  randerImages=new Back_pic("pic1.jpg","pic2.png","pic3.png","pic4.jpg");
  backImages=new Back_pic("img1.jpg","img2.jpg","img3.jpg","img4.jpg");
  //create context for pixelFlow 
  context= new DwPixelFlow(this);
  buffers=new ArrayList<PImage>();
  
  //setup the diffusion shader
  grayScott_shader=context.createShader("grayscott.txt");
  //setup the render shader to color grayScott
  render_shader=context.createShader("render.txt");
  //dwPixelFlow setup
  dwTexture=new DwGLTexture();//dw shader layer
  dwTexture.resize(context,GL2.GL_RG32F,width,height,GL2.GL_RG,GL2.GL_FLOAT,GL2.GL_NEAREST,2,4);
  
  back_tex=new DwGLTexture();//used to feed into dw shader layer (for image filter)
  back_tex.resize(context,GL2.GL_RG32F,width,height,GL2.GL_RG,GL2.GL_FLOAT,GL2.GL_NEAREST,2,4);
  
  back_painting=new DwGLTexture();//used to feed into shader layer (for color)
  back_painting.resize(context,GL2.GL_RG32F,width,height,GL2.GL_RG,GL2.GL_FLOAT,GL2.GL_NEAREST,2,4);
  
  //setup the canvas layer
  canvas=(PGraphics2D)createGraphics(width,height,P2D);
  canvas.beginDraw();
  canvas.background(255,0.0,0.0);
  canvas.fill(0.0,255,0.0);
  canvas.noStroke();
  canvas.endDraw();
  
  output=createGraphics(width,height,P2D);
  
  DwFilter.get(context).copy.apply(canvas,dwTexture);
  
  //GUI SETUP;
  GUI();
  sv=new Save_file();


 frameRate(1000);
}

public void dwTexturePass(){
  context.beginDraw(dwTexture);
  grayScott_shader.begin();
  grayScott_shader.uniform1i("mode",filter_mode);
  grayScott_shader.uniform1f("da",da);
  grayScott_shader.uniform1f("db",db);
  grayScott_shader.uniform1f("k",k);
  grayScott_shader.uniform1f("f",f);
  grayScott_shader.uniform1f("dt",dt);
  grayScott_shader.uniform2f("wh",width,height);
  grayScott_shader.uniformTexture("tex",dwTexture);
  grayScott_shader.uniformTexture("painting",back_painting);
  grayScott_shader.drawFullScreenQuad();
  grayScott_shader.end();  
  context.endDraw("dwTexturePass()");
  //dwTexture.swap();
}

public void dwRenderShader(){
    context.beginDraw(canvas);
    render_shader.begin();
    render_shader.uniform2f("wh",width,height);
    render_shader.uniform3f("render_color",color_R(),color_G(),color_B());
    render_shader.uniform1i("mode",render_mode);
    render_shader.uniformTexture("tex",dwTexture);
    render_shader.uniformTexture("b_tex",back_tex);
    render_shader.drawFullScreenQuad();
    render_shader.end("render()");
    context.endDraw();
    context.end();
  
}
  

void draw(){
  if(firstTime){
  //Welcome Screen
    background(50);
    animation();
    
    textSize(72);
    
    welcomeTime+=1;
    if(welcomeTime<2500){
      float t=constrain(sq(welcomeTime)/200,50.0,255.0);
      fill(t);
      text("WELCOME TO DIFFUSION PAINTER",410,433);      
    }else if(welcomeTime<2800){
      float t=255-constrain(sq(welcomeTime-2500)/200,0,205);
      fill(t);
      text("WELCOME TO DIFFUSION PAINTER",410,433);       
    }else{
      firstTime=false;
    }
  }else{
     context.begin();
    //brush function copy dw texture out to canvas allowing mouth interaction
    if(mousePressed && boolean_controller){
      DwFilter.get(context).copy.apply(dwTexture, canvas);
      canvas.beginDraw();
      canvas.stroke(0,200,0);
      canvas.strokeWeight(15);
      canvas.line(pmouseX,pmouseY,mouseX,mouseY);
      canvas.endDraw(); 
      DwFilter.get(context).copy.apply(canvas,dwTexture);
      }
    //start reaction diffusion 
    if(boolean_start){
      //set background texture of diffusion shader to filter image
      if(filter_mode==1){
        backImages.copyToTexture(image_number,back_painting);
        println(55);
      }
      //Gray Scott shader
      for(int i=0;i<iteration;i++){
        dwTexturePass();
      }
    }
    
    //set background texture of render to set color gradiant    
    randerImages.copyToTexture(render_number,back_tex);
    //render_shader 
    dwRenderShader();
  
  
    if(saveBuffer){
      buffers.add(canvas.copy());
      canvas=(PGraphics2D)createGraphics(width,height,P2D);
      canvas.beginDraw();
      canvas.background(255,0.0,0.0);
      canvas.endDraw();
      DwFilter.get(context).copy.apply(canvas,dwTexture);
      saveBuffer=false;
      haveBuffer=true;
    }
    //legend text string
    String layers_num="Layers number:"+(buffers.size()+1);
    String frame_rate="Frame rate:"+(frameRate);
    String author="Creator: Tianzhu Zhang";
    String manuel="This painting program utilized Gray Scottreaction diffusion as its shader. You can save frame to composite your interesing art project.               Additional functions are use picture as color source and apply image filter";
    
    
    //update saved frames on screen
    if(haveBuffer){
    output.beginDraw();
    output.background(255);
    output.blendMode(MULTIPLY);
    for(PImage E:buffers){
      output.image(E,0,0);
    }
    output.image(canvas,0,0);
    output.textSize(12);
    output.fill(0);
    output.text(layers_num,width-210,45);
    output.text(frame_rate,width-210,65);
    output.text(author,width-210,85);
    output.text(manuel,200,height-40);
    output.endDraw();
    image(output,0,0);
    println("11");
    }
    else{
      //update screen while no saved frame
      output.beginDraw();
      output.background(255);
      output.blendMode(MULTIPLY);
      output.textSize(12);
      output.fill(0);
      output.text(layers_num,width-210,45);
      output.text(frame_rate,width-210,65);
      output.text(author,width-210,85);
      output.text(manuel,200,height-40);
      output.image(canvas,0,0);
      output.endDraw();
      image(output,0,0); 
    }  //update screen while no saved frame
  }

}

////////////////////////////////////////////////////////////
//base image
class Back_pic{
  PImage[] imgs;
  PGraphics2D pgs;
  PImage img_0;//backgounrd 0
  PImage img_1;//backgounrd 1
  PImage img_2;//backgounrd 2
  PImage img_3;//backgounrd 3
  
  PGraphics2D p_0;//backgounrd 0
  PGraphics2D p_1;//backgounrd 1
  PGraphics2D p_2;//backgounrd 2
  PGraphics2D p_3;//backgounrd 3
  
 Back_pic(String address_0,String address_1,String address_2,String address_3){
   p_0=(PGraphics2D)createGraphics(width,height,P2D);
   p_1=(PGraphics2D)createGraphics(width,height,P2D);
   p_2=(PGraphics2D)createGraphics(width,height,P2D);
   p_3=(PGraphics2D)createGraphics(width,height,P2D);
    
    this.img_0=loadImage(address_0);
    this.img_1=loadImage(address_1);
    this.img_2=loadImage(address_2);
    this.img_3=loadImage(address_3);
    
    this.img_0.resize(width,height);
    this.img_1.resize(width,height);
    this.img_2.resize(width,height);
    this.img_3.resize(width,height);
    
    this.p_0.beginDraw();
    this.p_0.background(this.img_0);
    this.p_0.endDraw();
    
    this.p_1.beginDraw();
    this.p_1.background(this.img_1);
    this.p_1.endDraw();
    
    this.p_2.beginDraw();
    this.p_2.background(this.img_2);
    this.p_2.endDraw();
    
    this.p_3.beginDraw();
    this.p_3.background(this.img_3);
    this.p_3.endDraw();
  }
  
  void copyToTexture(int a,DwGLTexture tex){
    switch(a){
      case 0:
        DwFilter.get(context).copy.apply(p_0, tex); 
        break;
      case 1:
        DwFilter.get(context).copy.apply(p_1, tex); 
        break;
      case 2:
        DwFilter.get(context).copy.apply(p_2, tex); 
        break;
      case 3:
        DwFilter.get(context).copy.apply(p_3, tex); 
        break;
    }
  }
  
}

void animation(){
  int pos=abs((welcomeTime/3)%200-100);
  float c=map(abs((welcomeTime/3)%100-50),0.0,50.0,0.0,255.0);
  fill(c,255,255);
  ellipse(width/2+50-pos,height/2,20,20);
  
}
////////////////////////////////////////////////////////////////
void GUI(){
  p5=new ControlP5(this);
  
  //value range of coefficient
  float r_da=2.0;
  float r_db=2.0;
  float r_f=0.2;
  float r_k=0.2;
  float r_dt=1.5;
  float r_iter=1.0;
  
  Group g1=p5.addGroup("myGroup1")
  .setBackgroundColor(color(0,64))
  .setBackgroundHeight(280)
  .setLabel("coefficient");
  
  
  p5.addSlider("da")
  .setPosition(10,20)
  .setSize((int)r_da*100,10)
  .setRange(0.0,r_da)
  .setValue(1.0)
  .setGroup(g1);
  
  p5.addSlider("db")
  .setPosition(10,40)
  .setSize((int)r_db*100,10)
  .setRange(0.0,r_db)
  .setValue(.5)
  .setGroup(g1);
    
  p5.addSlider("f")
  .setPosition(10,60)
  .setSize(ceil(r_f)*200,10)
  .setRange(0.0,r_f)
  .setValue(.055)
  .setGroup(g1);
    
  p5.addSlider("k")
  .setPosition(10,80)
  .setSize(ceil(r_k)*200,10)
  .setRange(0.0,r_k)
  .setValue(.062)
  .setGroup(g1);

   p5.addSlider("dt")
  .setPosition(10,100)
  .setSize((int)r_dt*100,10)
  .setRange(0.0,r_dt)
  .setValue(1.0)
  .setGroup(g1);
  
   p5.addSlider("iteration")
  .setPosition(10,100)
  .setSize((int)r_iter*100,10)
  .setRange(0.0,r_iter*100)
  .setValue(10.0)
  .setGroup(g1);
  

  p5.addBang("bang_start")
    .setPosition(10,160)
    .setSize(30,30)
    .setGroup(g1)
    ;
    
  p5.addBang("bang_saveframe")
    .setPosition(90,160)
    .setSize(30,30)
    .setGroup(g1)
    ;
    
  p5.addBang("erase_current")
    .setPosition(170,160)
    .setSize(30,30)
    .setGroup(g1)
    ;
    
  p5.addBang("erase_all")
    .setPosition(250,160)
    .setSize(30,30)
    .setGroup(g1)
    ;
    
  p5.addBang("save_button")
    .setPosition(10,220)
    .setSize(120,30)
    .setGroup(g1)
    ;
    

  Group g2=p5.addGroup("myGroup2")
    .setBackgroundColor(color(0,64))
    .setBackgroundHeight(200)
    .setLabel("color");
///////////////////////////////////////////////////////////// 
//color picker
    cp=p5.addColorPicker("picker")
    .setPosition(10,20)
    .setColorValue(color(255,5,264,255))
    .setGroup(g2);
    
    p5.addToggle("toggle_render")
     .setPosition(10,90)
     .setSize(50,20)
     .setValue(false)
     .setMode(ControlP5.SWITCH)
     .setGroup(g2)
     ;
     
    p5.addToggle("toggle_filter")
     .setPosition(120,90)
     .setSize(50,20)
     .setValue(false)
     .setMode(ControlP5.SWITCH)
     .setGroup(g2)
     ;
    
    p5.addBang("render_selector")
    .setPosition(10,140)
    .setSize(30,30)
    .setGroup(g2)
    ;
    
    p5.addBang("filter_selector")
    .setPosition(120,140)
    .setSize(30,30)
    .setGroup(g2)
    ;
    

////////////////////////////////////////////////////////////////  
//accordior
  accordion=p5.addAccordion("Manu")
              .setPosition(30,30)
              .setWidth(300)
              .addItem(g1)
              .addItem(g2)
              ;
  
  accordion.setCollapseMode(Accordion.MULTI);
}
//responding cp5 functions
public void bang_start(){
  boolean_start=!boolean_start; 
}

public void erase_current(){
  canvas.beginDraw();
  canvas.background(255,0,0);
  canvas.endDraw();
  DwFilter.get(context).copy.apply(canvas,dwTexture);
}

public void erase_all(){
  canvas.beginDraw();
  canvas.background(255,0,0);
  canvas.endDraw();
  DwFilter.get(context).copy.apply(canvas,dwTexture);
  for(int i=0; i<buffers.size();i++){
    buffers.remove(i);
  }
}

public void bang_saveframe(){
  saveBuffer=true;
}

public void save_button(){
  sv.save_to();
}

public void toggle_render(boolean flag){
  if(flag) render_mode=1;
  else render_mode=0;
}
public void toggle_filter(boolean flag){
  if(flag) filter_mode=1;
  else filter_mode=0;
}

public void render_selector(){
  if(render_number<4){
    render_number+=1;
  }else{
    render_number=0;
  }
}

public void filter_selector(){
  if(image_number<4){
    image_number+=1;
  }else{
    image_number=0;
  }
}

//turn color into 0-255 int
public float color_R(){
  float c=red(color(cp.getColorValue()));
  float colorR=map(c,0.0,255.0,0.0,1.0);
  return colorR;
  
}
public float color_G(){
  float c=green(color(cp.getColorValue()));
  float colorG=map(c,0.0,255.0,0.0,1.0);
  return colorG;
  
}
public float color_B(){
  float c=blue(color(cp.getColorValue()));
  float colorB=map(c,0.0,255.0,0.0,1.0);
  return colorB;
  
}
public float color_A(){
  float c=alpha(color(cp.getColorValue()));
  float colorA=map(c,0.0,255.0,0.0,1.0);
  return colorA;
  
}

//////////////////////////////////////////////////////////////////////
//prevent bushing paints onto canvas while controlling
void controlEvent(ControlEvent theEvent) {
  if(theEvent.isGroup()) {
    pauseBrush();
    startBrush();
    println("got an event from group "
            +theEvent.getGroup().getName()
            +", isOpen? "+theEvent.getGroup().isOpen()
            );
            
  } else if (theEvent.isController()){
    if(theEvent.getController().isInside()){
      pauseBrush();
    }else{
      startBrush();
    }
    println("got something from a controller "
            +theEvent.getController().getName()
            );
  }
}

//to prevent drawing on screen while clicking bottons
void mousePressed(){
  startBrush();
}

public void pauseBrush(){
    boolean_controller=false;

}
public void startBrush(){
    boolean_controller=true;
}
/////////////////////////////////////////////////////////////
class Save_file{
  String file_type;
  int file_number;
  
  public Save_file(){
    file_number=1;
    this.file_type=".png";
  }
  
  public void save_to(){
    String path="ArtPiece"+file_number+file_type;
    save(path);
    file_number++;
  }  
}