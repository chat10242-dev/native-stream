package com.nativeStream.asm;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Typeface;
import android.os.Bundle;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.content.SharedPreferences;
import android.widget.Toast;
import org.json.JSONArray;
import org.json.JSONObject;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.InetAddress;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.Iterator;
import java.util.Locale;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

public class MainActivity extends Activity {
    private static final int BG = Color.rgb(15, 19, 28);
    private final ArrayList<GameProfile> profiles = new ArrayList<>();
    private SharedPreferences prefs;
    private EditText hostField, portField, pinField;
    private LinearLayout profileList;
    private GameProfile activeProfile;

    private static final class Control {
        String action, label, icon;
        int type, code;
        float x, y;
        Control(String a, String l, String i, int t, int c, float px, float py) {
            action=a; label=l; icon=i; type=t; code=c; x=px; y=py;
        }
        JSONObject json() throws Exception {
            JSONObject o=new JSONObject(); o.put("action",action); o.put("label",label); o.put("icon",icon);
            o.put("type",type); o.put("code",code); o.put("x",x); o.put("y",y); return o;
        }
    }
    private static final class GameProfile {
        String name; ArrayList<Control> controls=new ArrayList<>();
        GameProfile(String n) { name=n; defaults(); }
        void defaults() {
            controls.clear();
            controls.add(new Control("MOVE","Movimento","◉",4,0,0.18f,0.73f));
            controls.add(new Control("AIM","Mira","⌖",2,273,0.72f,0.67f)); // BTN_RIGHT
            controls.add(new Control("FIRE","Fuoco","●",2,272,0.88f,0.52f)); // BTN_LEFT
            controls.add(new Control("JUMP","Salto","↑",1,57,0.87f,0.79f));
            controls.add(new Control("RELOAD","Ricarica","R",1,19,0.74f,0.86f));
            controls.add(new Control("USE","Usa","E",1,18,0.96f,0.77f));
            controls.add(new Control("CROUCH","Accovacciati","↓",1,46,0.96f,0.91f));
        }
        static GameProfile platformSample() {
            GameProfile p=new GameProfile("Platform · esempio"); p.controls.clear();
            p.controls.add(new Control("MOVE","Movimento","◉",4,0,0.18f,0.73f));
            p.controls.add(new Control("JUMP","Salto","↑",1,57,0.84f,0.77f));
            p.controls.add(new Control("ATTACK","Attacco","✦",1,45,0.95f,0.61f));
            p.controls.add(new Control("USE","Azione","E",1,18,0.72f,0.88f));
            return p;
        }
        JSONObject json() throws Exception {
            JSONObject o=new JSONObject(); o.put("name",name); JSONArray a=new JSONArray();
            for(Control c:controls) a.put(c.json()); o.put("controls",a); return o;
        }
        static GameProfile from(JSONObject o) throws Exception {
            GameProfile p=new GameProfile(o.optString("name","Gioco")); p.controls.clear();
            JSONArray a=o.optJSONArray("controls");
            if(a!=null) for(int i=0;i<a.length();i++) { JSONObject c=a.getJSONObject(i);
                p.controls.add(new Control(c.optString("action"),c.optString("label"),c.optString("icon"),
                    c.optInt("type",1),c.optInt("code",57),(float)c.optDouble("x",.8),(float)c.optDouble("y",.8))); }
            return p;
        }
    }

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        prefs=getSharedPreferences("native_stream",MODE_PRIVATE);
        loadProfiles();
        if(profiles.isEmpty()) { profiles.add(new GameProfile("FPS · esempio")); profiles.add(GameProfile.platformSample()); saveProfiles(); }
        showHome();
    }

    private int dp(float v) { return (int)(v*getResources().getDisplayMetrics().density+.5f); }
    private TextView text(String value,int size) {
        TextView t=new TextView(this); t.setText(value); t.setTextSize(size); t.setTextColor(Color.WHITE); return t;
    }
    private Button button(String value) {
        Button b=new Button(this); b.setText(value); b.setTextColor(Color.WHITE); b.setAllCaps(false); return b;
    }
    private void showHome() {
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN);
        getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        LinearLayout root=new LinearLayout(this); root.setOrientation(LinearLayout.VERTICAL); root.setPadding(dp(18),dp(18),dp(18),dp(12)); root.setBackgroundColor(BG);
        TextView title=text("NATIVESTREAM  /  TOUCH PROFILES",22); title.setTypeface(null,Typeface.BOLD); root.addView(title);
        TextView sub=text("Esempi pronti: FPS e platform · personalizza posizione e tasti",14); sub.setTextColor(Color.LTGRAY); root.addView(sub);
        hostField=new EditText(this); hostField.setSingleLine(); hostField.setHint("IPv4 host raggiungibile"); hostField.setText(prefs.getString("host","")); root.addView(hostField);
        portField=new EditText(this); portField.setSingleLine(); portField.setInputType(2); portField.setHint("Porta stream (default 47999)"); portField.setText(prefs.getString("port","47999")); root.addView(portField);
        pinField=new EditText(this); pinField.setSingleLine(); pinField.setHint("PIN host"); pinField.setText(prefs.getString("pin","")); root.addView(pinField);
        Button add=button("＋  Crea profilo per un gioco"); add.setOnClickListener(v->createProfile()); root.addView(add);
        ScrollView scroll=new ScrollView(this); profileList=new LinearLayout(this); profileList.setOrientation(LinearLayout.VERTICAL); scroll.addView(profileList);
        root.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        TextView note=text("Area senza pulsanti: trascina il dito per muovere il mouse. I pulsanti inviano tasti o click al PC. Richiede host raggiungibile e /dev/uinput configurato.",13); note.setTextColor(Color.LTGRAY); root.addView(note);
        setContentView(root); refreshProfiles();
    }
    private void refreshProfiles() {
        if(profileList==null)return; profileList.removeAllViews();
        for(GameProfile p:profiles) {
            LinearLayout row=new LinearLayout(this); row.setGravity(Gravity.CENTER_VERTICAL);
            Button open=button("🎮  "+p.name+"   ·   Apri layout"); open.setOnClickListener(v->openProfile(p));
            open.setOnLongClickListener(v->{editProfileName(p);return true;}); row.addView(open,new LinearLayout.LayoutParams(0,dp(58),1));
            Button remove=button("×"); remove.setOnClickListener(v->{profiles.remove(p);saveProfiles();refreshProfiles();}); row.addView(remove);
            profileList.addView(row);
        }
    }
    private void createProfile() {
        EditText input=new EditText(this); input.setHint("Nome gioco, es. Apex Legends");
        new AlertDialog.Builder(this).setTitle("Nuovo profilo gioco").setView(input)
            .setNegativeButton("Annulla",null).setPositiveButton("Crea",(d,w)->{
                String n=input.getText().toString().trim(); if(n.isEmpty())n="Nuovo gioco";
                GameProfile p=new GameProfile(n); profiles.add(p); saveProfiles(); refreshProfiles(); openProfile(p);
            }).show();
    }
    private void editProfileName(GameProfile p) {
        EditText input=new EditText(this); input.setText(p.name);
        new AlertDialog.Builder(this).setTitle("Rinomina profilo").setView(input)
            .setNegativeButton("Annulla",null).setPositiveButton("Salva",(d,w)->{p.name=input.getText().toString().trim();saveProfiles();refreshProfiles();}).show();
    }
    private void openProfile(GameProfile p) {
        if(hostField!=null) prefs.edit().putString("host",hostField.getText().toString().trim())
            .putString("port",portField.getText().toString().trim()).putString("pin",pinField.getText().toString()).apply();
        activeProfile=p; setRequestedOrientation(0); getWindow().addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN|WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        setContentView(new TouchSurface(p));
    }
    @Override public void onBackPressed() {
        if(activeProfile!=null) { activeProfile=null; setRequestedOrientation(-1); showHome(); }
        else super.onBackPressed();
    }
    private void loadProfiles() {
        try { JSONArray a=new JSONArray(prefs.getString("profiles","[]")); for(int i=0;i<a.length();i++) profiles.add(GameProfile.from(a.getJSONObject(i))); }
        catch(Exception ignored) { profiles.clear(); }
    }
    private void saveProfiles() {
        JSONArray a=new JSONArray(); try { for(GameProfile p:profiles)a.put(p.json()); } catch(Exception ignored){}
        prefs.edit().putString("profiles",a.toString()).apply();
    }

    private final class TouchSurface extends View {
        final GameProfile profile; final Paint paint=new Paint(3);
        final HashMap<Integer,Control> held=new HashMap<>();
        final HashMap<Integer,float[]> previous=new HashMap<>();
        final ScheduledExecutorService sender=Executors.newSingleThreadScheduledExecutor();
        DatagramSocket socket; InetAddress host; int inputPort; boolean editing=false;
        Control dragging; float dragDx,dragDy,dragStartX,dragStartY; boolean dragMoved=false;
        TouchSurface(GameProfile p) { super(MainActivity.this); profile=p; setBackgroundColor(Color.rgb(22,27,38)); connectInput(); setFocusable(true); }
        void connectInput() {
            try {
                String ip=prefs.getString("host",""); int port=Integer.parseInt(prefs.getString("port","47999"));
                String pin=prefs.getString("pin",""); if(ip.isEmpty()||pin.isEmpty())return;
                host=InetAddress.getByName(ip); inputPort=port+1; socket=new DatagramSocket();
                final byte[] hello=("NSINPUT:"+pin).getBytes(); sender.scheduleAtFixedRate(()->sendBytes(hello),0,1,TimeUnit.SECONDS);
            } catch(Exception e) { Toast.makeText(MainActivity.this,"Configura IP, porta e PIN host",Toast.LENGTH_LONG).show(); }
        }
        void sendBytes(byte[] bytes) { try { if(socket!=null&&host!=null)socket.send(new DatagramPacket(bytes,bytes.length,host,inputPort)); } catch(Exception ignored){} }
        void sendEvent(int type,int down,int code,int dx,int dy) {
            ByteBuffer b=ByteBuffer.allocate(16).order(ByteOrder.BIG_ENDIAN);
            b.putInt(0x4e53494e).put((byte)type).put((byte)down).putShort((short)code).putInt(dx).putInt(dy);
            byte[] data=b.array(); sender.execute(()->sendBytes(data));
        }
        float radius(Control a) { return Math.max(dp(25),Math.min(getWidth(),getHeight())*(a.type==4?.13f:.055f)); }
        Control hit(float x,float y) { for(int i=profile.controls.size()-1;i>=0;i--){Control a=profile.controls.get(i);float dx=x-a.x*getWidth(),dy=y-a.y*getHeight(),r=radius(a);if(dx*dx+dy*dy<r*r*1.5f)return a;}return null; }
        @Override protected void onDraw(Canvas c) {
            super.onDraw(c); float w=getWidth(),h=getHeight();
            paint.setColor(0x99ffffff);paint.setTextSize(dp(14));paint.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));
            c.drawText(profile.name+"  ·  "+(editing?"EDITOR: trascina i pulsanti / tocca per cambiare tasto":"TOCCA I PULSANTI · AREA LIBERA = MOUSE"),dp(18),dp(28),paint);
            paint.setColor(editing?0xffe2a72e:0xff48566b);c.drawRoundRect(w-dp(204),dp(7),w-dp(112),dp(38),dp(9),dp(9),paint);
            paint.setColor(Color.WHITE);paint.setTextSize(dp(12));c.drawText(editing?"GIOCA":"MODIFICA",w-dp(193),dp(28),paint);
            paint.setColor(0xff285f83);c.drawRoundRect(w-dp(105),dp(7),w-dp(18),dp(38),dp(9),dp(9),paint);
            paint.setColor(Color.WHITE);c.drawText("SALVA",w-dp(87),dp(28),paint);
            for(Control a:profile.controls) {
                float x=a.x*w,y=a.y*h,r=radius(a); paint.setColor(editing?0xb33f89b5:(a.type==4?0x664d8aa4:0x772f91bb));c.drawCircle(x,y,r,paint);
                paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(dp(2));paint.setColor(a.action.equals("AIM")?0xff65d5ff:0xbbeeffff);c.drawCircle(x,y,r,paint);paint.setStyle(Paint.Style.FILL);
                if(a.type==4){paint.setColor(0x885ac5e8);c.drawCircle(x,y,r*.48f,paint);paint.setColor(Color.WHITE);paint.setTextAlign(Paint.Align.CENTER);paint.setTextSize(dp(19));c.drawText("◉",x,y+dp(7),paint);paint.setTextAlign(Paint.Align.LEFT);}
                else {paint.setColor(Color.WHITE);paint.setTypeface(Typeface.create("sans-serif",Typeface.BOLD));paint.setTextAlign(Paint.Align.CENTER);paint.setTextSize(a.action.equals("AIM")?r*.88f:r*.68f);c.drawText(a.icon,x,y+r*.28f,paint);}
                String binding=a.type==4?new String[]{"WASD","Frecce","IJKL"}[Math.max(0,Math.min(2,a.code))]:(a.type==2?(a.code==273?"RMB":"LMB"):linuxKeyName(a.code));
                paint.setTextSize(dp(10));paint.setColor(0xffe9f6ff);c.drawText(a.label+" · "+binding,x,y+r+dp(14),paint);paint.setTextAlign(Paint.Align.LEFT);
            }
            if(!editing) { paint.setColor(0x77ffffff);paint.setTextSize(dp(16));paint.setTextAlign(Paint.Align.CENTER);c.drawText("ANTEPRIMA VIDEO NON ANCORA COLLEGATA",w*.5f,h*.44f,paint);paint.setTextSize(dp(12));c.drawText("Trascina un'area libera per muovere la visuale",w*.5f,h*.44f+dp(25),paint);paint.setTextAlign(Paint.Align.LEFT); }
        }
        void chooseBinding(Control a) {
            if(a.type==4){
                final String[] layouts={"W A S D","Frecce direzionali","I J K L"};
                new AlertDialog.Builder(MainActivity.this).setTitle("Movimento · "+profile.name).setItems(layouts,(d,n)->{a.code=n;invalidate();saveProfiles();}).show();
                return;
            }
            final String[] choices={"Mouse: mira / tasto destro","Mouse: fuoco / tasto sinistro","W","A","S","D","Spazio","Shift","Ctrl","E","R","Q","F","C","X","G"};
            final int[] types={2,2,1,1,1,1,1,1,1,1,1,1,1,1,1,1};
            final int[] codes={273,272,17,30,31,32,57,42,29,18,19,16,33,46,45,34};
            new AlertDialog.Builder(MainActivity.this).setTitle("Associa "+a.label+" per "+profile.name).setItems(choices,(d,n)->{a.type=types[n];a.code=codes[n];a.icon=(a.action.equals("AIM")?"⌖":choices[n]);invalidate();saveProfiles();}).show();
        }
        boolean topButton(float x,float y) { return y<dp(45)&&x>getWidth()-dp(212); }
        @Override public boolean onTouchEvent(MotionEvent e) {
            int action=e.getActionMasked(), index=e.getActionIndex(), id=e.getPointerId(index);
            if(action==MotionEvent.ACTION_DOWN||action==MotionEvent.ACTION_POINTER_DOWN) {
                float x=e.getX(index),y=e.getY(index);
                if(topButton(x,y)) { if(x>getWidth()-dp(108)){saveProfiles();Toast.makeText(MainActivity.this,"Profilo salvato",Toast.LENGTH_SHORT).show();}else editing=!editing;invalidate();return true; }
                Control a=hit(x,y);
                if(editing) { if(a!=null){dragging=a;dragMoved=false;dragStartX=x;dragStartY=y;dragDx=x-a.x*getWidth();dragDy=y-a.y*getHeight();} return true; }
                if(a!=null) { held.put(id,a);if(a.type!=4)sendEvent(a.type,1,a.code,0,0); }
                previous.put(id,new float[]{x,y}); invalidate(); return true;
            }
            if(action==MotionEvent.ACTION_MOVE) {
                if(editing&&dragging!=null) { float x=e.getX(),y=e.getY();if(Math.abs(x-dragStartX)+Math.abs(y-dragStartY)>dp(7))dragMoved=true;dragging.x=Math.max(.04f,Math.min(.97f,(x-dragDx)/getWidth()));dragging.y=Math.max(.08f,Math.min(.96f,(y-dragDy)/getHeight()));invalidate();return true; }
                for(int i=0;i<e.getPointerCount();i++){int pid=e.getPointerId(i);float x=e.getX(i),y=e.getY(i);float[] old=previous.get(pid);Control active=held.get(pid);if(active!=null&&active.type==4){float cx=active.x*getWidth(),cy=active.y*getHeight(),r=radius(active);int ax=Math.max(-1000,Math.min(1000,Math.round((x-cx)/r*1000))),ay=Math.max(-1000,Math.min(1000,Math.round((y-cy)/r*1000)));sendEvent(4,0,0,ax,ay);}else if(old!=null&&active==null){int dx=Math.round((x-old[0])*1.8f),dy=Math.round((y-old[1])*1.8f);if(dx!=0||dy!=0)sendEvent(3,0,0,dx,dy);}previous.put(pid,new float[]{x,y});}
                return true;
            }
            if(action==MotionEvent.ACTION_UP||action==MotionEvent.ACTION_POINTER_UP||action==MotionEvent.ACTION_CANCEL) {
                if(action==MotionEvent.ACTION_CANCEL){for(Control c:held.values())if(c.type!=4)sendEvent(c.type,0,c.code,0,0);held.clear();previous.clear();sendEvent(5,0,0,0,0);invalidate();return true;}
                Control a=held.remove(id);if(a!=null){if(a.type==4)sendEvent(4,0,0,0,0);else sendEvent(a.type,0,a.code,0,0);}previous.remove(id);
                if(editing&&dragging!=null){Control selected=dragging;dragging=null;if(!dragMoved)chooseBinding(selected);else saveProfiles();}
                invalidate();return true;
            }
            return true;
        }
        @Override protected void onDetachedFromWindow() { sendEvent(5,0,0,0,0);super.onDetachedFromWindow();sender.shutdown();if(socket!=null)socket.close(); }
    }
    private String linuxKeyName(int code) { switch(code){case 57:return "SPACE";case 42:return "SHIFT";case 29:return "CTRL";case 18:return "E";case 19:return "R";case 17:return "W";case 30:return "A";case 31:return "S";case 32:return "D";default:return "KEY";} }
}
