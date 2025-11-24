# Integrating Spring Boot with Environment Variables or Azure Key Vault

This guide explains how to configure **Spring Boot applications** to load sensitive configuration values (like Temporal Cloud API keys) securely—either from **environment variables** or **Azure Key Vault**.

---

## 🔧 Prerequisites

- Spring Boot 3.x
- Temporal Java SDK with [Spring Boot Autoconfigure](https://github.com/temporalio/sdk-java/tree/master/temporal-spring-boot-autoconfigure)
- Access to Azure Key Vault (if using the Key Vault option)
- Spring Cloud Azure dependencies (for Key Vault integration)
- Build tool: Maven **or** Gradle

---

## 1. Configure Temporal Connection via Environment Variables

Spring Boot supports **externalized configuration**, meaning you can provide settings from environment variables, command-line arguments, or files.

### Example `application.yml`

```yaml
temporal:
  connection:
    target: ${TEMPORAL_ADDRESS:your-namespace.tmprl.cloud:7233}
    namespace: ${TEMPORAL_NAMESPACE:your-namespace}
    api-key: ${TEMPORAL_API_KEY}
    tls:
      enabled: true
```

### Environment Variables

```bash
export TEMPORAL_ADDRESS="your-namespace.tmprl.cloud:7233"
export TEMPORAL_NAMESPACE="your-namespace"
export TEMPORAL_API_KEY="tskc_************"
```

Spring will automatically resolve `${TEMPORAL_API_KEY}` and bind it to `temporal.connection.api-key`.

> 🧠 **Tip:** Spring Boot’s *relaxed binding* allows property names like `api-key` and `apiKey` to be used interchangeably.

---

## 2. Configure Temporal Connection via Azure Key Vault

If your organization stores secrets in **Azure Key Vault**, you can load them as Spring Boot configuration properties using **Spring Cloud Azure**.

### Step 1: Add Dependencies

#### Maven

```xml
<dependencyManagement>
  <dependencies>
    <dependency>
      <groupId>com.azure.spring</groupId>
      <artifactId>spring-cloud-azure-dependencies</artifactId>
      <version>5.9.0</version> <!-- use the latest available version -->
      <type>pom</type>
      <scope>import</scope>
    </dependency>
  </dependencies>
</dependencyManagement>

<dependencies>
  <dependency>
    <groupId>com.azure.spring</groupId>
    <artifactId>spring-cloud-azure-starter-keyvault-secrets</artifactId>
  </dependency>
</dependencies>
```

#### Gradle

```groovy
implementation platform("com.azure.spring:spring-cloud-azure-dependencies:5.9.0") // or latest
implementation 'com.azure.spring:spring-cloud-azure-starter-keyvault-secrets'
```

---

### Step 2: Configure Key Vault Access

Add your Azure credentials and Key Vault name to `application.yml`:

```yaml
spring:
  cloud:
    azure:
      keyvault:
        secret:
          enabled: true
          endpoint: https://<your-key-vault-name>.vault.azure.net/
```

> You can authenticate with **Managed Identity (recommended)** or **service principal** credentials.

---

### Step 3: Reference Secrets in Your Application Configuration

When Spring Cloud Azure loads Key Vault secrets, they are available as regular Spring properties.  
If your Key Vault has a secret named `temporal-api-key`, you can reference it like this:

```yaml
temporal:
  connection:
    api-key: ${temporal-api-key}
    target: ${TEMPORAL_ADDRESS:your-namespace.tmprl.cloud:7233}
    namespace: ${TEMPORAL_NAMESPACE:your-namespace}
    tls:
      enabled: true
```

That’s it — no code changes needed. Spring Boot automatically injects the Key Vault secret into the Temporal connection configuration.

---

## 3. Verify the Configuration

To verify that your Temporal client picks up the right credentials, you can log the connection info (excluding the key):

```java
import io.temporal.client.WorkflowClient;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.CommandLineRunner;
import org.springframework.stereotype.Component;

@Component
public class TemporalVerifier implements CommandLineRunner {

    @Autowired
    private WorkflowClient client;

    @Override
    public void run(String... args) {
        System.out.println("Connected to Temporal namespace: " + client.getOptions().getNamespace());
    }
}
```

---

## 4. Summary

| Source | Method | Configuration Example |
|--------|---------|------------------------|
| **Environment Variables** | Spring Boot placeholder (`${VAR}`) | `${TEMPORAL_API_KEY}` |
| **Azure Key Vault** | Spring Cloud Azure Key Vault integration | `${temporal-api-key}` |

Both methods bind cleanly into Spring Boot’s property resolution chain, letting you externalize secrets without modifying application code.

---

## 🛡️ Best Practices

- Never commit API keys or secrets into version control.
- Prefer **Managed Identity** authentication for Azure.
- Use **`application.yml`** for readability and environment placeholders.
- Validate secret resolution at startup with a simple test bean.
- Rotate keys periodically and leverage **Key Vault’s auto-rotation** where possible.

---

✅ **This `README.md` is complete — you can download or copy it directly into your repository or internal documentation.**
