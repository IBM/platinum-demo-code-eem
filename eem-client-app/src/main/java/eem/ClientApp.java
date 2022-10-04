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
package eem;

import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.CommonClientConfigs;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;


import org.apache.avro.Schema;
import org.apache.avro.generic.GenericDatumReader;
import org.apache.avro.generic.GenericRecord;
import java.io.File;
import org.apache.kafka.common.config.SaslConfigs;
import org.apache.kafka.common.config.SslConfigs;

import com.google.gson.JsonElement;
import com.google.gson.JsonObject;
import com.google.gson.JsonParser;

public class ClientApp {
  public static final void main(String args[]) {

	String gatewayEndpoint = System.getenv("GATEWAY_ENDPOINT");
	String kafkaClientId = System.getenv("KAFKA_CLIENT_ID");
	String gatewayUsername = System.getenv("GATEWAY_USERNAME");
	String gatewayPassword = System.getenv("GATEWAY_PASSWORD");
	String flightNumber = System.getenv("FLIGHT_NUMBER");
	Schema.Parser schemaDefinitionParser = new Schema.Parser();
    Properties props = new Properties();

    props.put("bootstrap.servers", gatewayEndpoint);
    props.put("key.deserializer", "org.apache.kafka.common.serialization.StringDeserializer");
    props.put("value.deserializer", "org.apache.kafka.common.serialization.ByteArrayDeserializer");

    props.put("group.id", "1");
    props.put("client.id", kafkaClientId);

    props.put(CommonClientConfigs.SECURITY_PROTOCOL_CONFIG, "SASL_SSL");

    props.put(SaslConfigs.SASL_MECHANISM, "PLAIN");
    props.put(SaslConfigs.SASL_JAAS_CONFIG,
      "org.apache.kafka.common.security.plain.PlainLoginModule required " +
      "username=\""+gatewayUsername+"\" " +
      "password=\""+gatewayPassword+"\";");
    // The Kafka cluster may have encryption enabled. Contact the API owner for the appropriate TrustStore configuration.
    props.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, "/etc/ssl/eem/eem.jks");
    //props.put(SslConfigs.SSL_TRUSTSTORE_LOCATION_CONFIG, "c://temp//eem.jks");
    props.put(SslConfigs.SSL_TRUSTSTORE_PASSWORD_CONFIG, "password");
    props.put(SslConfigs.SSL_TRUSTSTORE_TYPE_CONFIG, "JKS");
    props.put("ssl.endpoint.identification.algorithm", "");

    KafkaConsumer consumer = new KafkaConsumer<String, byte[]>(props);
    consumer.subscribe(Collections.singletonList("flight-delays"));
    try {
      while(true) {

        ConsumerRecords<String, byte[]> records = consumer.poll(Duration.ofSeconds(1));
        for (ConsumerRecord<String, byte[]> record : records) {
        	byte[] value = record.value();
            JsonElement jsonElement = JsonParser.parseString(new String(value));
            JsonObject flightDetails = jsonElement.getAsJsonObject();
            String eventFlightId = flightDetails.get("id").getAsString();
            if(flightNumber==null || flightNumber.length()<1 || eventFlightId.equals(flightNumber))
            {
            	System.out.println("");
            	System.out.println("#########################################################");
            	System.out.println("Your flight "+flightNumber+" has been delayed by "+flightDetails.get("delay").getAsInt()+" minutes.");
            	System.out.println("Why not pop back to the ACME Restaurant and have a meal at a 10% discount?");
            	System.out.println("Would you like to book a table before the others on your plane take them all!");
            	System.out.println("#########################################################");
            	System.out.println("");
            }
          }
        }
    } catch (Exception e) {
      e.printStackTrace();
      consumer.close();
      System.exit(1);
    }
  }
}
