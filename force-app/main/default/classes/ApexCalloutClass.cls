public class ApexCalloutClass {
	// construct the request
	// method to send the HTTP call to the Gemini API
	// method to handle and parse the response
	// method to authenticate the request using API key
	private static Gemini_API_Configuration__mdt cachedConfig;
    
    private static Gemini_API_Configuration__mdt getConfig(){
        
        List<Gemini_API_Configuration__mdt> configs;
        if(cachedConfig == null){
            configs = [select MasterLabel,API_Key__c, API_Endpoint__c, Model_Name__c, Is_Active__c
                		FROM Gemini_API_Configuration__mdt 
                		WHERE Is_Active__c = true 
                		LIMIT 1];
            
            if(configs.isEmpty()){
            	throw new ConfigurationException('No active Gemini API configuration found. Please configure in Setup → Custom Metadata Types → Gemini API Configuration.');
        	}
            cachedConfig = configs[0];
        }
        return cachedConfig;
    }
    
    // get the full endpoint URL with model
    private static string getEndPointUrl(){
        Gemini_API_Configuration__mdt config = getConfig();
		return config.API_Endpoint__c+'/'+config.Model_Name__c+':generateContent';
    }
    
    private static string getApiKey(){
        Gemini_API_Configuration__mdt config = getConfig();
        if(string.isBlank(config.API_Key__c)){
            throw new ConfigurationException('API Key is not configured in Custom Metadata.');
        }
        return config.API_Key__c;
    }
    
    // Main method that sends HTTP request to Gemini API
    public static string sendGeminiRequest(string prompt){
        try{
           string apiKey = getApiKey();
            
            HttpRequest request = constructRequest(prompt,apiKey);
            
            Http http = new Http();
            HttpResponse response = http.send(request);
             return handleResponse(response);
            
        } catch(Exception e){
            system.debug('Error in sendGeminiRequest:'+ e.getMessage());
             throw new AuraHandledException('Failed to call Gemini API: ' + e.getMessage());
        }
    }
    
    private static HttpRequest constructRequest(string prompt, string apiKey){
        HttpRequest request = new HttpRequest();
        
        string endpoint = getEndpointUrl()+'?key='+apiKey;
        
        request.setEndpoint(endpoint);
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setTimeout(60000);
        
        Map<string,object> requestBody = buildRequestBody(prompt);
        request.setBody(JSON.serialize(requestBody));
        
        System.debug('Gemini Endpoint: ' + getEndpointUrl());
        System.debug('Request Body: ' + JSON.serializePretty(requestBody));
        
        return request;
    }
    
	
    private static Map<string, object> buildRequestBody(string prompt){
        map<string, object> requestBody = new map<string, object>();
        
        list<map<string, string>> parts = new list<map<string, string>>();
        parts.add(new map<string, string>{'text'=> prompt});
        
        map<string,object> content = new map<string,object>();
        content.put('parts',parts);
        
        List<Map<String, Object>> contents = new List<Map<String, Object>>();
        contents.add(content);
        
        requestBody.put('contents', contents);
        
        Map<String, Object> generationConfig = new Map<String, Object>{
            'temperature' => 0.7,
            'maxOutputTokens' => 1024,
            'topP' => 0.8,
            'topK' => 40
        };
            
        requestBody.put('generationConfig', generationConfig);
        
        return requestBody;
    }  
    
    /*
     * Handle HTTP response and check for errors
     */
    private static String handleResponse(HttpResponse response) {
        Integer statusCode = response.getStatusCode();
        String responseBody = response.getBody();
        
        System.debug('Gemini API Status Code: ' + statusCode);
        System.debug('Gemini API Response: ' + responseBody);
        
        if (statusCode == 200) {
            return parseGeminiResponse(responseBody);
        } else {
            throw new AuraHandledException('Gemini API Error [' + statusCode + ']: ' + responseBody);
        }
    }
    
    /**
     * Parse Gemini's JSON response structure and extract generated text
     */
    private static String parseGeminiResponse(String responseBody) {
        try {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
            
            List<Object> candidates = (List<Object>) responseMap.get('candidates');
            
            if (candidates != null && !candidates.isEmpty()) {
                Map<String, Object> firstCandidate = (Map<String, Object>) candidates[0];
                Map<String, Object> content = (Map<String, Object>) firstCandidate.get('content');
                List<Object> parts = (List<Object>) content.get('parts');
                
                if (parts != null && !parts.isEmpty()) {
                    Map<String, Object> firstPart = (Map<String, Object>) parts[0];
                    String generatedText = (String) firstPart.get('text');
                    
                    System.debug('Generated Text: ' + generatedText);
                    return generatedText;
                }
            }
            
            throw new AuraHandledException('No content found in Gemini response');
            
        } catch (Exception e) {
            System.debug('Error parsing Gemini response: ' + e.getMessage());
            throw new AuraHandledException('Failed to parse Gemini response: ' + e.getMessage());
        }
    }
    
    /**
     * Test configuration - useful for debugging
     */
    @AuraEnabled
    public static String testConfiguration() {
        try {
            Gemini_API_Configuration__mdt config = getConfig();
            
            String result = 'Configuration Status:\n';
            result += '✓ Active Config: ' + config.MasterLabel + '\n';  // Changed Label to MasterLabel
            result += '✓ API Endpoint: ' + config.API_Endpoint__c + '\n';
            result += '✓ Model Name: ' + config.Model_Name__c + '\n';
            result += '✓ API Key: ' + (String.isNotBlank(config.API_Key__c) ? 'Configured (' + config.API_Key__c.length() + ' chars)' : 'MISSING') + '\n';
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Configuration Error: ' + e.getMessage());
        }
    }
    
    /**
     * Test actual API call with a simple prompt
     */
    @AuraEnabled
    public static String testApiCall() {
        try {
            String testPrompt = 'Say "Hello! Connection successful!" if you can read this.';
            String response = sendGeminiRequest(testPrompt);
            return 'SUCCESS! Gemini Response: ' + response;
        } catch (Exception e) {
            throw new AuraHandledException('API Test Failed: ' + e.getMessage());
        }
    }
    
    /**
     * Custom exception for configuration errors
     */
    public class ConfigurationException extends Exception {}
}