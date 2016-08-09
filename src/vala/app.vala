using Gst;
using Clutter;
using ClutterGst;
using Gee;

public class ApplicationInfoHandler : GLib.Object, InfoHandler {
    private HashMap<string, string> _map = new HashMap<string, string>();

    public HashMap<string, string> map {
        get { return _map; }
    }

    public HashMap<string, string> getInfoMap () {
      return this._map;
    }
}

public class ApplicationMetricsHandler: GLib.Object, MetricsHandler {

}

public class Application: GLib.Object {

  private string pipeline_template = "filesrc name=src ! decodebin name=d ! queue ! videoconvert ! video/x-raw,format=RGBA ! queue ! clutterautovideosink name=videosink  d. ! queue ! audioconvert ! autoaudiosink";

  private Pipeline pipeline;
  private Gst.Bus bus;
  private MainLoop loop;
  private Element src;
  private Stage stage;
  private Actor videoframe;
  private Playback player;
  private string file;
  private ApplicationMetricsHandler metricsHandler = new ApplicationMetricsHandler();
  private ApplicationInfoHandler infoHandler = new ApplicationInfoHandler();

  public Application() {
    int port = 8088;
    Controller controller = new Controller (this.infoHandler, this.metricsHandler);
    controller.listen_all (port, 0);
    //controller.got_shutdown.connect (this.shutdown);
    controller.got_start.connect (this.startPlayer);
    controller.got_stop.connect (this.stopPlayer);
    controller.add_handler ("/mediafiles", this.mediafiles_handler);
    controller.add_handler ("/actions/select", this.select_handler);

	stage = new Stage();
	stage.set_size(1280, 738);
	stage.background_color = Color () { alpha = 255 };

	stage.show ();

    // Creating pipeline and elements
    pipeline = (Pipeline)parse_launch(pipeline_template);


    bus = pipeline.get_bus();
    bus.add_watch (0, bus_callback);
  }

  private void select_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable<string, string>? query, Soup.ClientContext client) {
    if(msg.method == "POST") {
      stdout.printf ("Select request recieved.\n");
      msg.set_status(Soup.Status.OK);

      unowned string selection = query.get("name");
      if(selection != null) {
        this.file = selection;
      }
    }
  }

  private void mediafiles_handler (Soup.Server server, Soup.Message msg, string path, GLib.HashTable? query, Soup.ClientContext client) {
    if(msg.method == "GET") {
      stdout.printf ("Media files request recieved.\n");
      msg.set_status(Soup.Status.OK);
      string[] files = {"CO16_D_01_Thm.mp4", "CO16_D_02_Clk.mp4", "CO16_D_03_Prld.mp4", "CO16_D_04_102.mp4", "CO16_D_05_No01-1.mp4", "CO16_D_06_No02-1.mp4"};
      string message = "[";
      int count = 0;
    	foreach (string file in files) {
  		    stdout.printf ("%s\n", file);
          if(count > 0) {
            message += ",";
          }
          message += "\n\t{";
          message += "\n\t\t";
          message += "\"name\": ";
          message += "\""+ this.escape_json_value(file) + "\"";
          message += "\n\t}";
          count++;
    	}
      message+="\n]";
      stdout.printf ("Sending Media files request.\n");
      msg.set_response("application/json", Soup.MemoryUse.COPY, message.data);
    }
  }


  private bool bus_callback (Gst.Bus bus, Gst.Message message) {
    switch (message.type) {
        case MessageType.ERROR:
            GLib.Error err;
            string debug;
            message.parse_error (out err, out debug);
            stdout.printf ("Error: %s\n", err.message);
            loop.quit ();
            break;
        case MessageType.EOS:
            stdout.printf ("end of stream\n");
            break;
        case MessageType.STATE_CHANGED:
            Gst.State oldstate;
            Gst.State newstate;
            Gst.State pending;
            message.parse_state_changed (out oldstate, out newstate,
                                         out pending);
            stdout.printf ("state changed: %s->%s:%s\n",
                           oldstate.to_string (), newstate.to_string (),
                           pending.to_string ());
            break;
        default:
            break;
        }

        return true;
  }

  public void startPlayer() {
    player = new Playback();

  	ClutterGst.Content content = new ClutterGst.Aspectratio();
  	content.player = player;

    videoframe = new Actor();
  	videoframe.content = content;
    videoframe.width = 1280;
  	videoframe.height = 738;

    Point point = Point.alloc();
    point.init(0.5f,0.5f) ;
    videoframe.pivot_point = point;

  	stage.add_child (videoframe);

    player.set_filename(this.file);
    player.set_audio_volume(1);
    player.set_playing(true);

  }

  public void stopPlayer() {
      player.set_playing(false);
      stage.remove_child(videoframe);
  }

  public void start() {
	//src = pipeline.get_by_name("src");
	//src.set_property("location", "test.mp4");

	//Element videosink = pipeline.get_by_name("videosink");
	//videosink.set_property("content", videoframe);

    // Set pipeline state to PLAYING
    //pipeline.set_state (Gst.State.PLAYING);




    // Creating and starting a GLib main loop
    loop = new MainLoop();
    loop.run ();
  }

  public string escape_json_value(string value) {
    return value.replace("\"", "\\\"");
  }

  public static int main (string[] args) {
	if ( Clutter.init (ref args) < 0) {
        stderr.printf("Failed to initialize clutter\n");
        return 1;
    }
      Gst.init (ref args);

      var app = new Application ();
      app.start();

      return 0;


  }
}
