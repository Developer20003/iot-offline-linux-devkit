import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRebalanceListener;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.consumer.OffsetAndMetadata;
import org.apache.kafka.common.TopicPartition;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Collection;
import java.util.Collections;
import java.util.Map;
import java.util.Properties;

public final class OfflineKafkaThingsBoardBridge {

    private static final ObjectMapper JSON = new ObjectMapper();

    private static String config(String name, String defaultValue) {
        String value = System.getenv(name);
        return value == null || value.isBlank()
                ? defaultValue : value;
    }

    public static void main(String[] args) throws Exception {

        String broker = config(
                "OFFLINE_KAFKA_BROKER", "iot-kafka:19092");

        String kafkaTopic = config(
                "OFFLINE_KAFKA_TOPIC", "iot-telemetry");

        String expectedTopic = config(
                "OFFLINE_MQTT_TOPIC",
                "iot/telemetry/Offline_Telemetry_Test");

        String expectedDevice = config(
                "OFFLINE_DEVICE_NAME", "Offline_Telemetry_Test");

        String thingsboard = config(
                "OFFLINE_THINGSBOARD_URL",
                "http://iot-thingsboard:8080"
        ).replaceAll("/+$", "");

        String tokenFile = config(
                "TB_DEVICE_TOKEN_FILE",
                "/run/secrets/offline_tb_device_token");

        String token = Files.readString(
                Path.of(tokenFile), StandardCharsets.UTF_8
        ).strip();

        if (token.isEmpty()) {
            throw new IllegalStateException(
                    "ThingsBoard device token file is empty");
        }

        String encodedToken = URLEncoder.encode(
                token, StandardCharsets.UTF_8);

        URI telemetryUri = URI.create(
                thingsboard + "/api/v1/"
                + encodedToken + "/telemetry");

        HttpClient http = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(5))
                .build();

        Properties props = new Properties();

        props.put(
                ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, broker);

        props.put(
                ConsumerConfig.GROUP_ID_CONFIG,
                "offline-kafka-thingsboard-v1");

        props.put(
                ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");

        props.put(
                ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "latest");

        props.put(
                ConsumerConfig.MAX_POLL_RECORDS_CONFIG, "1");

        props.put(
                ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG,
                StringDeserializer.class.getName());

        props.put(
                ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG,
                StringDeserializer.class.getName());

        System.out.println(
                "OFFLINE BRIDGE: STARTING");

        System.out.println(
                "KAFKA TOPIC: " + kafkaTopic);

        System.out.println(
                "TARGET DEVICE: " + expectedDevice);

        try (KafkaConsumer<String, String> consumer =
                     new KafkaConsumer<>(props)) {

            consumer.subscribe(
                Collections.singletonList(kafkaTopic),
                new ConsumerRebalanceListener() {

                    @Override
                    public void onPartitionsRevoked(
                            Collection<TopicPartition> partitions) {
                        System.out.println(
                            "PARTITIONS REVOKED: " + partitions);
                    }

                    @Override
                    public void onPartitionsAssigned(
                            Collection<TopicPartition> partitions) {
                        System.out.println(
                            "KAFKA PARTITIONS ASSIGNED: " + partitions);
                    }
                });

            while (true) {

                ConsumerRecords<String, String> records =
                        consumer.poll(Duration.ofSeconds(1));

                for (ConsumerRecord<String, String> record : records) {

                    JsonNode envelope = JSON.readTree(record.value());

                    if (envelope == null || !envelope.isObject()) {
                        throw new IllegalArgumentException(
                                "Invalid Kafka envelope at offset "
                                + record.offset());
                    }

                    String mqttTopic = envelope.path("topic")
                            .asText("");

                    if (!expectedTopic.equals(mqttTopic)) {
                        System.out.println(
                                "SKIPPED OTHER TOPIC: " + mqttTopic);
                    } else {

                        JsonNode payload = envelope.path("payload");

                        if (payload.isTextual()) {
                            payload = JSON.readTree(payload.asText());
                        }

                        if (payload == null || !payload.isObject()) {
                            throw new IllegalArgumentException(
                                    "Invalid telemetry payload");
                        }

                        String deviceName = payload.path("device_name")
                                .asText("");

                        if (!expectedDevice.equals(deviceName)) {
                            throw new IllegalArgumentException(
                                    "Device identity mismatch");
                        }

                        String telemetryJson =
                                JSON.writeValueAsString(payload);

                        HttpRequest request = HttpRequest.newBuilder()
                                .uri(telemetryUri)
                                .timeout(Duration.ofSeconds(15))
                                .header(
                                        "Content-Type",
                                        "application/json")
                                .POST(
                                        HttpRequest.BodyPublishers
                                                .ofString(telemetryJson))
                                .build();

                        HttpResponse<String> response = http.send(
                                request,
                                HttpResponse.BodyHandlers.ofString());

                        int status = response.statusCode();

                        if (status != 200 && status != 204) {
                            throw new IllegalStateException(
                                    "ThingsBoard telemetry rejected: HTTP "
                                    + status);
                        }

                        System.out.println(
                                "THINGSBOARD TELEMETRY FORWARDED: "
                                + payload.path("test_id").asText("no-test-id"));
                    }

                    TopicPartition partition = new TopicPartition(
                            record.topic(), record.partition());

                    consumer.commitSync(
                            Map.of(
                                partition,
                                new OffsetAndMetadata(
                                    record.offset() + 1,
                                    record.leaderEpoch(),
                                    ""
                                )
                            )
                    );

                    System.out.println(
                            "KAFKA OFFSET COMMITTED: "
                            + (record.offset() + 1));
                }
            }
        }
    }
}
