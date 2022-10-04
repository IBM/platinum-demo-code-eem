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

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;

import javax.json.bind.annotation.JsonbDateFormat;
import javax.json.bind.annotation.JsonbProperty;

public class Flight implements Comparable{

    @JsonbProperty(nillable=true)
    private String id;

    @JsonbProperty(nillable=true)
    private String number;

    @JsonbProperty(nillable=true)
    private String origin;

    @JsonbProperty(nillable=true)
    private String destination;

    //@JsonbProperty(nillable=true)
    //private String scheduledDeparture;

    @JsonbProperty(nillable=true)
    private int delay;

    @JsonbProperty(nillable=true)
    @JsonbDateFormat("HH:mm")
    private LocalTime scheduledArrivalTime;

    @JsonbProperty(nillable=true)
    @JsonbDateFormat("yyyy-MM-dd")
    private LocalDate scheduledArrivalDate;

    @JsonbProperty(nillable=true)
    @JsonbDateFormat("HH:mm")
    private LocalTime scheduledDepartureTime;

    @JsonbProperty(nillable=true)
    @JsonbDateFormat("yyyy-MM-dd")
    private LocalDate scheduledDepartureDate;

    @JsonbProperty(nillable=true)
    @JsonbDateFormat("yyyy-MM-dd:HH:mm")
    private LocalDateTime estimatedDepartureTime;

    private String carrier;
    private String originCode;
    private String destinationCode;

    private Status status;

    public enum Status {
        SCHEDULED,
        DEPARTED,
        LANDED
    }

    public Flight() {

    }

    /*public Flight(ScheduledFlight sf) {
        this.number = sf.getNumber();
        this.carrier = sf.getCarrier();
        this.origin = sf.getOrigin();
        this.originCode = sf.getOriginCode();
        this.destination = sf.getDestination();
        this.destinationCode = sf.getDestinationCode();
        this.scheduledDepartureDate = sf.getScheduledDepartureDate();
        this.scheduledDepartureTime = sf.getScheduledDepartureTime();
        this.delay = 0;
        this.estimatedDepartureTime = LocalDateTime.of(sf.getScheduledDepartureDate(), sf.getScheduledDepartureTime());
    }*/

    public void delay(int minutes) {
        delay = minutes;
        this.estimatedDepartureTime = LocalDateTime.of(this.scheduledDepartureDate, this.scheduledDepartureTime).plusMinutes(delay);
    }

    public String getId() {
        return this.id;
    }

    public void setId(String id) {
        this.id = id;
    }

    public LocalDate getScheduledArrivalDate() {
        return this.scheduledArrivalDate;
    }

    public void setScheduledArrivalDate(LocalDate scheduledArrivalDate) {
        this.scheduledArrivalDate = scheduledArrivalDate;
    }

    public LocalDate getScheduledDepartureDate() {
        return this.scheduledDepartureDate;
    }

    public void setScheduledDepartureDate(LocalDate scheduledDepartureDate) {
        this.scheduledDepartureDate = scheduledDepartureDate;
    }

    public String getNumber() {
        return this.number;
    }

    public void setNumber(String number) {
        this.number = number;
        this.id = number;
    }

    public String getOrigin() {
        return this.origin;
    }

    public void setOrigin(String origin) {
        this.origin = origin;
    }

    public String getDestination() {
        return this.destination;
    }

    public void setDestination(String destination) {
        this.destination = destination;
    }

    public LocalTime getScheduledDepartureTime() {
        return this.scheduledDepartureTime;
    }

    public void setScheduledDepartureTime(LocalTime scheduledDepartureTime) {
        this.scheduledDepartureTime = scheduledDepartureTime;
    }

    public LocalTime getScheduledArrivalTime() {
        return this.scheduledArrivalTime;
    }

    public void setScheduledArrivalTime(LocalTime scheduledArrivalTime) {
        this.scheduledArrivalTime = scheduledArrivalTime;
    }

    public int getDelay() {
        return this.delay;
    }

    public void setDelay(int delay) {
        this.delay = delay;
    }

    public Status getStatus() {
        return status;
    }

    public void setStatus(Status status) {
        this.status = status;
    }

    public String getCarrier(String carrier) {
        return this.carrier;
    }

    public void setCarrier(String carrier) {
        this.carrier = carrier;
    }

    public String getOriginCode() {
        return this.originCode;
    }

    public void setOriginCode(String originCode) {
        this.originCode = originCode;
    }

    public String getDestinationCode() {
        return this.destinationCode;
    }

    public void setDestinationCode(String destinationCode) {
        this.destinationCode = destinationCode;
    }

    public void setScheduledDeparture(String scheduledDeparture)
    {
      scheduledDepartureTime = LocalTime.parse(scheduledDeparture);
      scheduledDepartureDate = LocalDate.now();
      System.out.println(scheduledDepartureDate.toString()+"T"+scheduledDeparture);
      estimatedDepartureTime = LocalDateTime.parse(scheduledDepartureDate.toString()+"T"+scheduledDeparture);
    }

    public LocalDateTime getEstimatedDepartureTime() {
        return this.estimatedDepartureTime;
    }

    public void setEstimatedDepartureTime(LocalDateTime estimatedDepartureTime) {
        this.estimatedDepartureTime = estimatedDepartureTime;
    }

    public int compareTo(Object object)
    {
      Flight b = (Flight)object;
      if(this.getScheduledDepartureTime().equals(b.getScheduledDepartureTime()))
      {
        return 0;
      }
      else if(this.getScheduledDepartureTime().isBefore(b.getScheduledDepartureTime()))
      {
        return -1;
      }
      return 1;
    }

}
