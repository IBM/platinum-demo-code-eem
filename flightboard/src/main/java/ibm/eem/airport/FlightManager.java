/* © Copyright IBM Corporation 2022

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License. */
package ibm.eem.airport;

import java.io.ByteArrayInputStream;
import java.io.StringReader;
import java.io.InputStream;
import java.io.IOException;
import java.io.FileInputStream;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.logging.Logger;

import javax.json.Json;
import javax.json.JsonArray;
import javax.json.JsonObject;
import javax.json.JsonReader;
import javax.json.JsonValue;
import javax.json.bind.Jsonb;
import javax.json.bind.JsonbBuilder;
import javax.json.bind.JsonbException;
import javax.ws.rs.ProcessingException;
import javax.ws.rs.client.Client;
import javax.ws.rs.client.ClientBuilder;
import javax.ws.rs.client.Entity;
import javax.ws.rs.client.WebTarget;
import javax.ws.rs.core.MediaType;
import javax.ws.rs.core.Response;
import java.util.logging.FileHandler;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.logging.SimpleFormatter;

public class FlightManager {

    public static String KAFKA_REST_URL_ENV = "KAFKA_REST_URL";
    public static String KAFKA_TOPIC_ENV = "KAFKA_TOPIC";

    public static String KAFKA_REST_URL;
    public static String KAFKA_TOPIC;

    private Jsonb jb;
    private static Map<String, Flight> flightsDB = new HashMap<String, Flight>();

    private static Logger log = Logger.getLogger("FlightManager");
    {
      KAFKA_REST_URL = System.getenv(KAFKA_REST_URL_ENV);
      KAFKA_TOPIC = System.getenv(KAFKA_TOPIC_ENV);

    }
    static {
      FileHandler handler;
  		try
  		{
  			handler = new FileHandler("Flight.log");
  			handler.setFormatter(new SimpleFormatter());
  			handler.setLevel(Level.ALL);
  			log.addHandler(handler);
  		}
  		catch (SecurityException e)
  		{
  			e.printStackTrace();
  		}
  		catch (IOException e) {
  			e.printStackTrace();
  		}



	 }

    public FlightManager()
    {
        synchronized(flightsDB)
        {
          if(flightsDB.size()==0)
          {
            log.info("User Directory="+System.getProperty("user.dir"));
            System.out.println("User Directory="+System.getProperty("user.dir"));
            jb = JsonbBuilder.create();

            try
            {
              InputStream is = new FileInputStream("/etc/db.json");
              JsonReader jr = Json.createReader(is);

              JsonObject docListResponse = jr.readObject();
              JsonArray docs = docListResponse.getJsonArray("departures");

              for (JsonValue docObj : docs) {
                  String id = docObj.asJsonObject().getString("number");
                  if (!id.startsWith("_design")) {
                      String jsonString = docObj.asJsonObject().toString();
                      System.out.println("jsonString="+jsonString);
                      Flight f = jb.fromJson(jsonString, Flight.class);
                      flightsDB.put(id, f);
                  }
              }
            }
            catch(Exception e)
            {
              e.printStackTrace();
            }
            log.info("Loaded flight data="+flightsDB);
          }
        }
    }

    public Map<String, Flight> getAllFlights() throws Exception
    {
        return flightsDB;
    }

    public Flight getFlight(LocalDate d, String number) throws JsonbException {

        log.info("Getting flight " + number + " on " + d.toString());
        return flightsDB.get(number);
    }

    public void delayFlight(LocalDate d, String number, int minutes) throws Exception {

        Flight flight = flightsDB.get(number);
        flight.setDelay(flight.getDelay()+minutes);
        flight.setEstimatedDepartureTime(flight.getEstimatedDepartureTime().plusMinutes(minutes));
        sendDelayToKafka(flight);
    }

    private void sendDelayToKafka(Flight f) {

        try {
            Client client = ClientBuilder.newClient();
            WebTarget target = client.target(KAFKA_REST_URL + "/" + KAFKA_TOPIC + "/records");
            Response resp = target.request(MediaType.APPLICATION_JSON)
                .accept(MediaType.APPLICATION_JSON)
                .post(Entity.json(f), Response.class);
        } catch (ProcessingException e) {
            System.out.println("Exception caught");
            e.printStackTrace(System.out);
        }
    }
}
