import { LightningElement, api, track } from 'lwc';
import getOpportunityContext from '@salesforce/apex/GeminiAiApexIntegrationHelper.getOpportunityContext';
import generateEmail from '@salesforce/apex/GeminiAiApexIntegrationHelper.generateEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class AiEmailGenerator extends LightningElement {
    @api recordId; // Automatically gets Opportunity Id from record page
    
    @track generatedEmail = '';
    @track isLoading = false;
    @track showEmail = false;
    @track selectedTone = 'professional';

    // Tone options for dropdown
    get toneOptions() {
        return [
            { label: 'Professional', value: 'professional' },
            { label: 'Friendly', value: 'friendly' },
            { label: 'Direct', value: 'direct' }
        ];
    }

    // Check if email has been generated
    get isEmailGenerated() {
        return this.generatedEmail && this.generatedEmail.length > 0;
    }

    // Handle tone selection change
    handleToneChange(event) {
        this.selectedTone = event.detail.value;
    }

    // Main method to generate email
    async handleGenerate() {
        this.isLoading = true;
        this.showEmail = false;
        
        try {
            // Step 1: Get opportunity context
            const context = await getOpportunityContext({ oppId: this.recordId });
            
            // Step 2: Generate email using AI
            const email = await generateEmail({ 
                contextData: context,
                tone: this.selectedTone 
            });
            
            this.generatedEmail = email;
            this.showEmail = true;
            
            this.showToast('Success', 'Email generated successfully!', 'success');
            
        } catch (error) {
            console.error('Error generating email:', error);
            const errorMessage = error.body?.message || error.message || 'Failed to generate email';
            this.showToast('Error', errorMessage, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // Copy email to clipboard
    handleCopy() {
        const textArea = this.template.querySelector('lightning-textarea');
        if (textArea) {
            // Create temporary textarea for copying
            const tempTextArea = document.createElement('textarea');
            tempTextArea.value = this.generatedEmail;
            document.body.appendChild(tempTextArea);
            tempTextArea.select();
            document.execCommand('copy');
            document.body.removeChild(tempTextArea);
            
            this.showToast('Success', 'Email copied to clipboard!', 'success');
        }
    }

    // Handle manual edits to generated email
    handleEmailChange(event) {
        this.generatedEmail = event.detail.value;
    }

    // Show toast notification
    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(event);
    }
}