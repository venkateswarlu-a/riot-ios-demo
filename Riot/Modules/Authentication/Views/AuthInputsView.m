/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 Copyright 2019 New Vector Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "AuthInputsView.h"

#import "ThemeService.h"
#import "Tools.h"

#import "CountryPickerViewController.h"
#import "NBPhoneNumberUtil.h"

#import "RiotNavigationController.h"

@interface AuthInputsView ()
{
    /**
     The current email validation
     */
    MXK3PID  *submittedEmail;
    
    /**
     The current msisdn validation
     */
    MXK3PID  *submittedMSISDN;
    UINavigationController *phoneNumberPickerNavigationController;
    CountryPickerViewController *phoneNumberCountryPicker;
    NBPhoneNumber *nbPhoneNumber;
    
    /**
     The set of parameters ready to use for a registration.
     */
    NSDictionary *externalRegistrationParameters;
}

/**
 The current view container displayed at last position.
 */
@property (nonatomic) UIView *currentLastContainer;

@end

@implementation AuthInputsView
@synthesize softLogoutCredentials;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass(self)
                          bundle:[NSBundle bundleForClass:self]];
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    _thirdPartyIdentifiersHidden = YES;
    _isThirdPartyIdentifierPending = NO;
    _isSingleSignOnRequired = NO;
    
    self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_id_placeholder", @"Vector", nil);
    self.repeatPasswordTextField.placeholder = NSLocalizedStringFromTable(@"auth_repeat_password_placeholder", @"Vector", nil);
    self.passWordTextField.placeholder = NSLocalizedStringFromTable(@"auth_password_placeholder", @"Vector", nil);

    // Apply placeholder color
    [self customizeViewRendering];
}

- (void)destroy
{
    [super destroy];
    
    submittedEmail = nil;
    submittedMSISDN = nil;
}

-(void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_currentLastContainer)
    {
        self.currentLastContainer = _currentLastContainer;
    }
}

#pragma mark - Override MXKView

-(void)customizeViewRendering
{
    [super customizeViewRendering];
    
    self.repeatPasswordTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.userLoginTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.passWordTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.emailTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.phoneTextField.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.isoCountryCodeLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.callingCodeLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    
    self.messageLabel.textColor = ThemeService.shared.theme.textSecondaryColor;
    self.messageLabel.numberOfLines = 0;
    
    self.userLoginSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor;
    self.emailSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor;
    self.phoneSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor;
    self.passwordSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor;
    self.repeatPasswordSeparator.backgroundColor = ThemeService.shared.theme.lineBreakColor;

    [self.ssoButton.layer setCornerRadius:5];
    self.ssoButton.clipsToBounds = YES;
    [self.ssoButton setTitle:NSLocalizedStringFromTable(@"auth_login_single_sign_on", @"Vector", nil) forState:UIControlStateNormal];
    [self.ssoButton setTitle:NSLocalizedStringFromTable(@"auth_login_single_sign_on", @"Vector", nil) forState:UIControlStateHighlighted];
    self.ssoButton.backgroundColor = ThemeService.shared.theme.tintColor;

    if (self.userLoginTextField.placeholder)
    {
        self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                         initWithString:self.userLoginTextField.placeholder
                                                         attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }

    if (self.repeatPasswordTextField.placeholder)
    {
        self.repeatPasswordTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                              initWithString:self.repeatPasswordTextField.placeholder
                                                              attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];

    }

    if (self.passWordTextField.placeholder)
    {
        self.passWordTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                        initWithString:self.passWordTextField.placeholder
                                                        attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }

    if (self.phoneTextField.placeholder)
    {
        self.phoneTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                     initWithString:self.phoneTextField.placeholder
                                                     attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }

    if (self.emailTextField.placeholder)
    {
        self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                     initWithString:self.emailTextField.placeholder
                                                     attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
    }
}

#pragma mark -

- (BOOL)setAuthSession:(MXAuthenticationSession *)authSession withAuthType:(MXKAuthenticationType)authType;
{
    if (type == MXKAuthenticationTypeLogin || type == MXKAuthenticationTypeRegister)
    {
        // Validate first the provided session
        MXAuthenticationSession *validSession = [self validateAuthenticationSession:authSession];
        
        // Cancel email validation if any
        if (submittedEmail)
        {
            [submittedEmail cancelCurrentRequest];
            submittedEmail = nil;
        }
        
        // Cancel msisdn validation if any
        if (submittedMSISDN)
        {
            [submittedMSISDN cancelCurrentRequest];
            submittedMSISDN = nil;
        }
        
        // Reset external registration parameters
        externalRegistrationParameters = nil;
        
        // Reset UI by hidding all items
        [self hideInputsContainer];
        
        if ([super setAuthSession:validSession withAuthType:authType])
        {
            if (authType == MXKAuthenticationTypeLogin)
            {
                _isSingleSignOnRequired = NO;

                if ([self isFlowSupported:kMXLoginFlowTypePassword])
                {
                    self.passWordTextField.returnKeyType = UIReturnKeyDone;
                    self.phoneTextField.returnKeyType = UIReturnKeyNext;

                    self.userLoginTextField.placeholder = NSLocalizedStringFromTable(@"auth_user_id_placeholder", @"Vector", nil);
                    self.messageLabel.text = NSLocalizedStringFromTable(@"or", @"Vector", nil);
                    self.phoneTextField.placeholder = NSLocalizedStringFromTable(@"auth_phone_placeholder", @"Vector", nil);

                    self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                                     initWithString:self.userLoginTextField.placeholder
                                                                     attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
                    self.phoneTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                                 initWithString:self.phoneTextField.placeholder
                                                                 attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];

                    self.userLoginContainer.hidden = NO;
                    self.messageLabel.hidden = YES;
                    self.phoneContainer.hidden = YES;
                    self.passwordContainer.hidden = NO;

                    self.messageLabelTopConstraint.constant = 59;
                    self.phoneContainerTopConstraint.constant = 70;
                    self.passwordContainerTopConstraint.constant = 50;

                    self.currentLastContainer = self.passwordContainer;
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeCAS]
                         || [self isFlowSupported:kMXLoginFlowTypeSSO])
                {

                    self.ssoButtonContainer.hidden = NO;
                    self.currentLastContainer = self.ssoButtonContainer;

                    _isSingleSignOnRequired = YES;
                }
            }
            else
            {
                // Update the registration inputs layout by hidding third-party ids fields.
                self.thirdPartyIdentifiersHidden = _thirdPartyIdentifiersHidden;
            }
            
            return YES;
        }
    }
    
    return NO;
}

- (NSString*)validateParameters
{
    // Consider everything is fine when external registration parameters are ready to use
    if (externalRegistrationParameters)
    {
        return nil;
    }
    
    // Check the validity of the parameters
    NSString *errorMsg = nil;
    
    // Remove whitespace in user login text field
    NSString *userLogin = self.userLoginTextField.text;
    self.userLoginTextField.text = [userLogin stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    
    if (type == MXKAuthenticationTypeLogin)
    {
        if ([self isFlowSupported:kMXLoginFlowTypePassword])
        {
            // Check required fields
            if ((!self.userLoginTextField.text.length && !nbPhoneNumber) || !self.passWordTextField.text.length)
            {
                NSLog(@"[AuthInputsView] Invalid user/password");
                errorMsg = NSLocalizedStringFromTable(@"auth_invalid_login_param", @"Vector", nil);
            }
        }
        else
        {
            errorMsg = [NSBundle mxk_localizedStringForKey:@"not_supported_yet"];
        }
    }
    else if (type == MXKAuthenticationTypeRegister)
    {
        if (self.isThirdPartyIdentifiersHidden)
        {
            if (!self.userLoginTextField.text.length)
            {
                NSLog(@"[AuthInputsView] Invalid user name");
                errorMsg = NSLocalizedStringFromTable(@"auth_invalid_user_name", @"Vector", nil);
            }
            else if (!self.passWordTextField.text.length)
            {
                NSLog(@"[AuthInputsView] Missing Passwords");
                errorMsg = NSLocalizedStringFromTable(@"auth_missing_password", @"Vector", nil);
            }
            else if (self.passWordTextField.text.length < 6)
            {
                NSLog(@"[AuthInputsView] Invalid Passwords");
                errorMsg = NSLocalizedStringFromTable(@"auth_invalid_password", @"Vector", nil);
            }
            else if ([self.repeatPasswordTextField.text isEqualToString:self.passWordTextField.text] == NO)
            {
                NSLog(@"[AuthInputsView] Passwords don't match");
                errorMsg = NSLocalizedStringFromTable(@"auth_password_dont_match", @"Vector", nil);
            }
            else
            {
                // Check validity of the non empty user name
                NSString *user = self.userLoginTextField.text;
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^[a-z0-9.\\-_]+$" options:NSRegularExpressionCaseInsensitive error:nil];
                
                if ([regex firstMatchInString:user options:0 range:NSMakeRange(0, user.length)] == nil)
                {
                    NSLog(@"[AuthInputsView] Invalid user name");
                    errorMsg = NSLocalizedStringFromTable(@"auth_invalid_user_name", @"Vector", nil);
                }
            }
        }
        else
        {
            // Check email field
            if ([self isFlowSupported:kMXLoginFlowTypeEmailIdentity] && !self.emailTextField.text.length)
            {
                if (self.areAllThirdPartyIdentifiersRequired)
                {
                    NSLog(@"[AuthInputsView] Missing email");
                    errorMsg = NSLocalizedStringFromTable(@"auth_missing_email", @"Vector", nil);
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeMSISDN] && !self.phoneTextField.text.length && self.isThirdPartyIdentifierRequired)
                {
                    NSLog(@"[AuthInputsView] Missing email or phone number");
                    errorMsg = NSLocalizedStringFromTable(@"auth_missing_email_or_phone", @"Vector", nil);
                }
            }
            
            if (!errorMsg)
            {
                // Check phone field
                if ([self isFlowSupported:kMXLoginFlowTypeMSISDN] && !self.phoneTextField.text.length)
                {
                    if (self.areAllThirdPartyIdentifiersRequired)
                    {
                        NSLog(@"[AuthInputsView] Missing phone");
                        errorMsg = NSLocalizedStringFromTable(@"auth_missing_phone", @"Vector", nil);
                    }
                }
                
                if (!errorMsg)
                {
                    // Check email/phone validity
                    if (self.emailTextField.text.length)
                    {
                        // Check validity of the non empty email
                        if (![MXTools isEmailAddress:self.emailTextField.text])
                        {
                            NSLog(@"[AuthInputsView] Invalid email");
                            errorMsg = NSLocalizedStringFromTable(@"auth_invalid_email", @"Vector", nil);
                        }
                    }
                    
                    if (!errorMsg && nbPhoneNumber)
                    {
                        // Check validity of the non empty phone
                        if (![[NBPhoneNumberUtil sharedInstance] isValidNumber:nbPhoneNumber])
                        {
                            NSLog(@"[AuthInputsView] Invalid phone number");
                            errorMsg = NSLocalizedStringFromTable(@"auth_invalid_phone", @"Vector", nil);
                        }
                    }
                }
            }
        }
    }
    
    return errorMsg;
}

- (void)prepareParameters:(void (^)(NSDictionary *parameters, NSError *error))callback
{
    if (callback)
    {
        // Return external registration parameters if any
        if (externalRegistrationParameters)
        {
            // We trigger here a registration based on external inputs. All the required data are handled by the session id.
            NSLog(@"[AuthInputsView] prepareParameters: return external registration parameters");
            callback(externalRegistrationParameters, nil);
            
            // CAUTION: Do not reset this dictionary here, it is used later to handle this registration until the end (see [updateAuthSessionWithCompletedStages:didUpdateParameters:])
            
            return;
        }
        
        // Prepare here parameters dict by checking each required fields.
        NSDictionary *parameters = nil;
        
        // Check the validity of the parameters
        NSString *errorMsg = [self validateParameters];
        if (errorMsg)
        {
            if (inputsAlert)
            {
                [inputsAlert dismissViewControllerAnimated:NO completion:nil];
            }
            
            inputsAlert = [UIAlertController alertControllerWithTitle:[NSBundle mxk_localizedStringForKey:@"error"] message:errorMsg preferredStyle:UIAlertControllerStyleAlert];
            
            [inputsAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                             style:UIAlertActionStyleDefault
                                                           handler:^(UIAlertAction * action) {
                                                               
                                                               inputsAlert = nil;
                                                               
                                                           }]];
            
            [self.delegate authInputsView:self presentAlertController:inputsAlert];
        }
        else
        {
            // Handle here the supported login flow
            if (type == MXKAuthenticationTypeLogin)
            {
                if ([self isFlowSupported:kMXLoginFlowTypePassword])
                {
                    // Check whether the user login has been set.
                    NSString *user = self.userLoginTextField.text;
                    
                    if (user.length)
                    {
                        // Check whether user login is an email or a username.
                        if ([MXTools isEmailAddress:user])
                        {
                            parameters = @{
                                           @"type": kMXLoginFlowTypePassword,
                                           @"identifier": @{
                                                   @"type": kMXLoginIdentifierTypeThirdParty,
                                                   @"medium": kMX3PIDMediumEmail,
                                                   @"address": user
                                                   },
                                           @"password": self.passWordTextField.text,
                                           // Patch: add the old login api parameters for an email address (medium and address),
                                           // to keep logging in against old HS.
                                           @"medium": kMX3PIDMediumEmail,
                                           @"address": user
                                           };
                        }
                        else
                        {
                            parameters = @{
                                           @"type": kMXLoginFlowTypePassword,
                                           @"identifier": @{
                                                   @"type": kMXLoginIdentifierTypeUser,
                                                   @"user": user
                                                   },
                                           @"password": self.passWordTextField.text,
                                           // Patch: add the old login api parameters for a username (user),
                                           // to keep logging in against old HS.
                                           @"user": user
                                           };
                        }
                    }
                    else if (nbPhoneNumber)
                    {
                        NSString *countryCode = [[NBPhoneNumberUtil sharedInstance] getRegionCodeForNumber:nbPhoneNumber];
                        NSString *e164 = [[NBPhoneNumberUtil sharedInstance] format:nbPhoneNumber numberFormat:NBEPhoneNumberFormatE164 error:nil];
                        NSString *msisdn;
                        if ([e164 hasPrefix:@"+"])
                        {
                            msisdn = [e164 substringFromIndex:1];
                        }
                        else if ([e164 hasPrefix:@"00"])
                        {
                            msisdn = [e164 substringFromIndex:2];
                        }
                        
                        if (msisdn && countryCode)
                        {
                            parameters = @{
                                           @"type": kMXLoginFlowTypePassword,
                                           @"identifier": @{
                                                   @"type": kMXLoginIdentifierTypePhone,
                                                   @"country": countryCode,
                                                   @"number": msisdn
                                                   },
                                           @"password": self.passWordTextField.text
                                           };
                        }
                    }
                }

                // For soft logout, pass the device_id currently used
                if (parameters && self.softLogoutCredentials)
                {
                    NSMutableDictionary *parametersWithDeviceId = [parameters mutableCopy];
                    parametersWithDeviceId[@"device_id"] = self.softLogoutCredentials.deviceId;
                    parameters = parametersWithDeviceId;
                }

            }
            else if (type == MXKAuthenticationTypeRegister)
            {
                // Check whether a phone number has been set, and if it is not handled yet
                if (nbPhoneNumber && ![self isFlowCompleted:kMXLoginFlowTypeMSISDN])
                {
                    NSLog(@"[AuthInputsView] Prepare msisdn stage");
                    
                    // Retrieve the REST client from delegate
                    MXRestClient *restClient;
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
                    {
                        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
                    }
                    
                    if (restClient)
                    {
                        // Check whether a second 3pid is available
                        _isThirdPartyIdentifierPending = (!self.emailContainer.isHidden && self.emailTextField.text.length && ![self isFlowCompleted:kMXLoginFlowTypeEmailIdentity]);
                        
                        // Launch msisdn validation
                        NSString *e164 = [[NBPhoneNumberUtil sharedInstance] format:nbPhoneNumber numberFormat:NBEPhoneNumberFormatE164 error:nil];
                        NSString *msisdn;
                        if ([e164 hasPrefix:@"+"])
                        {
                            msisdn = [e164 substringFromIndex:1];
                        }
                        else if ([e164 hasPrefix:@"00"])
                        {
                            msisdn = [e164 substringFromIndex:2];
                        }
                        submittedMSISDN = [[MXK3PID alloc] initWithMedium:kMX3PIDMediumMSISDN andAddress:msisdn];
                        
                        [submittedMSISDN requestValidationTokenWithMatrixRestClient:restClient
                                                               isDuringRegistration:YES
                                                                           nextLink:nil
                                                                            success:^
                         {
                             
                             [self showValidationMSISDNDialogToPrepareParameters:callback];
                             
                         }
                                                                            failure:^(NSError *error)
                         {
                             
                             NSLog(@"[AuthInputsView] Failed to request msisdn token");
                             
                             // Ignore connection cancellation error
                             if (([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
                             {
                                 return;
                             }
                             
                             // Translate the potential MX error.
                             MXError *mxError = [[MXError alloc] initWithNSError:error];
                             if (mxError && ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse] || [mxError.errcode isEqualToString:kMXErrCodeStringServerNotTrusted]))
                             {
                                 NSMutableDictionary *userInfo;
                                 if (error.userInfo)
                                 {
                                     userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                                 }
                                 else
                                 {
                                     userInfo = [NSMutableDictionary dictionary];
                                 }
                                 
                                 userInfo[NSLocalizedFailureReasonErrorKey] = nil;
                                 
                                 if ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse])
                                 {
                                     userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_phone_in_use", @"Vector", nil);
                                     userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_phone_in_use", @"Vector", nil);
                                 }
                                 else
                                 {
                                     userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                                     userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                                 }
                                 
                                 error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
                             }
                             
                             callback(nil, error);
                             
                         }];
                        
                        // Async response
                        return;
                    }
                    NSLog(@"[AuthInputsView] Authentication failed during the msisdn stage");
                }
                // Check whether an email has been set, and if it is not handled yet
                else if (!self.emailContainer.isHidden && self.emailTextField.text.length && ![self isFlowCompleted:kMXLoginFlowTypeEmailIdentity])
                {
                    NSLog(@"[AuthInputsView] Prepare email identity stage");
                    
                    // Retrieve the REST client from delegate
                    MXRestClient *restClient;
                    
                    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
                    {
                        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
                    }
                    
                    if (restClient)
                    {
                        // Check whether a second 3pid is available
                        _isThirdPartyIdentifierPending = (nbPhoneNumber && ![self isFlowCompleted:kMXLoginFlowTypeMSISDN]);
                        
                        // Launch email validation
                        submittedEmail = [[MXK3PID alloc] initWithMedium:kMX3PIDMediumEmail andAddress:self.emailTextField.text];

                        // Create the next link that is common to all Vector.im clients
                        NSString *nextLink = [NSString stringWithFormat:@"%@/#/register?client_secret=%@&hs_url=%@&is_url=%@&session_id=%@",
                                              [Tools webAppUrl],
                                              [submittedEmail.clientSecret stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                                              [restClient.homeserver stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                                              [restClient.identityServer stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]],
                                              [currentSession.session stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];

                        [submittedEmail requestValidationTokenWithMatrixRestClient:restClient
                                                              isDuringRegistration:YES
                                                                          nextLink:nextLink
                                                                           success:^
                         {
                             
                             NSURL *identServerURL = [NSURL URLWithString:restClient.identityServer];
                             NSDictionary *parameters;
                             parameters = @{
                                            @"auth": @{@"session":currentSession.session, @"threepid_creds": @{@"client_secret": submittedEmail.clientSecret, @"id_server": identServerURL.host, @"sid": submittedEmail.sid}, @"type": kMXLoginFlowTypeEmailIdentity},
                                            @"username": self.userLoginTextField.text,
                                            @"password": self.passWordTextField.text,
                                            @"bind_msisdn": @([self isFlowCompleted:kMXLoginFlowTypeMSISDN]),
                                            @"bind_email": @(YES)
                                            };
                             
                             [self hideInputsContainer];
                             
                             self.messageLabel.text = NSLocalizedStringFromTable(@"auth_email_validation_message", @"Vector", nil);
                             self.messageLabel.hidden = YES;
                             
                             callback(parameters, nil);
                             
                         }
                                                                           failure:^(NSError *error)
                         {
                             
                             NSLog(@"[AuthInputsView] Failed to request email token");
                             
                             // Ignore connection cancellation error
                             if (([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
                             {
                                 return;
                             }
                             
                             // Translate the potential MX error.
                             MXError *mxError = [[MXError alloc] initWithNSError:error];
                             if (mxError && ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse] || [mxError.errcode isEqualToString:kMXErrCodeStringServerNotTrusted]))
                             {
                                 NSMutableDictionary *userInfo;
                                 if (error.userInfo)
                                 {
                                     userInfo = [NSMutableDictionary dictionaryWithDictionary:error.userInfo];
                                 }
                                 else
                                 {
                                     userInfo = [NSMutableDictionary dictionary];
                                 }
                                 
                                 userInfo[NSLocalizedFailureReasonErrorKey] = nil;
                                 
                                 if ([mxError.errcode isEqualToString:kMXErrCodeStringThreePIDInUse])
                                 {
                                     userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_email_in_use", @"Vector", nil);
                                     userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_email_in_use", @"Vector", nil);
                                 }
                                 else
                                 {
                                     userInfo[NSLocalizedDescriptionKey] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                                     userInfo[@"error"] = NSLocalizedStringFromTable(@"auth_untrusted_id_server", @"Vector", nil);
                                 }
                                 
                                 error = [NSError errorWithDomain:error.domain code:error.code userInfo:userInfo];
                             }
                             callback(nil, error);
                             
                         }];
                        
                        // Async response
                        return;
                    }
                    NSLog(@"[AuthInputsView] Authentication failed during the email identity stage");
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeRecaptcha] && ![self isFlowCompleted:kMXLoginFlowTypeRecaptcha])
                {
                    NSLog(@"[AuthInputsView] Prepare reCaptcha stage");
                    
                    [self displayRecaptchaForm:^(NSString *response) {
                        
                        if (response.length)
                        {
                            NSDictionary *parameters = @{
                                                         @"auth": @{@"session":currentSession.session, @"response": response, @"type": kMXLoginFlowTypeRecaptcha},
                                                         @"username": self.userLoginTextField.text,
                                                         @"password": self.passWordTextField.text,
                                                         @"bind_msisdn": @([self isFlowCompleted:kMXLoginFlowTypeMSISDN]),
                                                         @"bind_email": @([self isFlowCompleted:kMXLoginFlowTypeEmailIdentity])
                                                         };
                            
                            callback(parameters, nil);
                        }
                        else
                        {
                            NSLog(@"[AuthInputsView] reCaptcha stage failed");
                            callback(nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
                        }
                        
                    }];
                    
                    // Async response
                    return;
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeDummy] && ![self isFlowCompleted:kMXLoginFlowTypeDummy])
                {
                    parameters = @{
                                   @"auth": @{@"session":currentSession.session, @"type": kMXLoginFlowTypeDummy},
                                   @"username": self.userLoginTextField.text,
                                   @"password": self.passWordTextField.text,
                                   @"bind_msisdn": @(NO),
                                   @"bind_email": @(NO)
                                   };
                }
                else if ([self isFlowSupported:kMXLoginFlowTypePassword] && ![self isFlowCompleted:kMXLoginFlowTypePassword])
                {
                    // Note: this use case was not tested yet.
                    parameters = @{
                                   @"auth": @{
                                           @"session":currentSession.session,
                                           @"username": self.userLoginTextField.text,
                                           @"password": self.passWordTextField.text,
                                           @"type": kMXLoginFlowTypePassword
                                           }
                                   };
                }
                else if ([self isFlowSupported:kMXLoginFlowTypeTerms] && ![self isFlowCompleted:kMXLoginFlowTypeTerms])
                {
                    NSLog(@"[AuthInputsView] Prepare terms stage");

                    MXWeakify(self);
                    [self displayTermsView:^{
                        MXStrongifyAndReturnIfNil(self);

                        NSDictionary *parameters = @{
                                                     @"auth": @{
                                                             @"session":self->currentSession.session,
                                                             @"type": kMXLoginFlowTypeTerms
                                                             },
                                                     @"username": self.userLoginTextField.text,
                                                     @"password": self.passWordTextField.text,
                                                     @"bind_msisdn": @([self isFlowCompleted:kMXLoginFlowTypeMSISDN]),
                                                     @"bind_email": @([self isFlowCompleted:kMXLoginFlowTypeEmailIdentity])
                                                     };
                        callback(parameters, nil);
                    }];

                    // Async response
                    return;
                }
            }
        }
        
        callback(parameters, nil);
    }
}

- (void)updateAuthSessionWithCompletedStages:(NSArray *)completedStages didUpdateParameters:(void (^)(NSDictionary *parameters, NSError *error))callback
{
    if (callback)
    {
        if (currentSession)
        {
            currentSession.completed = completedStages;
            
            BOOL isMSISDNFlowCompleted = [self isFlowCompleted:kMXLoginFlowTypeMSISDN];
            BOOL isEmailFlowCompleted = [self isFlowCompleted:kMXLoginFlowTypeEmailIdentity];
            
            // Check the supported use cases
            if (isMSISDNFlowCompleted && self.isThirdPartyIdentifierPending)
            {
                NSLog(@"[AuthInputsView] Prepare a new third-party stage");
                
                // Here an email address is available, we add it to the authentication session.
                [self prepareParameters:callback];
                
                return;
            }
            else if ((isMSISDNFlowCompleted || isEmailFlowCompleted)
                     && [self isFlowSupported:kMXLoginFlowTypeRecaptcha] && ![self isFlowCompleted:kMXLoginFlowTypeRecaptcha])
            {
                NSLog(@"[AuthInputsView] Display reCaptcha stage");

                if (externalRegistrationParameters)
                {
                    [self displayRecaptchaForm:^(NSString *response) {

                        if (response.length)
                        {
                            // We finalize here a registration triggered from external inputs. All the required data are handled by the session id
                            NSDictionary *parameters = @{
                                           @"auth": @{@"session": currentSession.session, @"response": response, @"type": kMXLoginFlowTypeRecaptcha},
                                           };
                            callback (parameters, nil);
                        }
                        else
                        {
                            NSLog(@"[AuthInputsView] reCaptcha stage failed");
                            callback (nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
                        }
                    }];
                }
                else
                {
                    [self prepareParameters:callback];
                }
                
                return;
            }
            else if ([self isFlowSupported:kMXLoginFlowTypeTerms] && ![self isFlowCompleted:kMXLoginFlowTypeTerms])
            {
                NSLog(@"[AuthInputsView] Prepare a new terms stage");
                
                if (externalRegistrationParameters)
                {
                    [self displayTermsView:^{
                        
                        NSDictionary *parameters = @{
                                                     @"auth": @{
                                                             @"session":self->currentSession.session,
                                                             @"type": kMXLoginFlowTypeTerms
                                                             }
                                                     };
                        callback(parameters, nil);
                    }];
                }
                else
                {
                    [self prepareParameters:callback];
                }

                return;
            }
        }
        
        NSLog(@"[AuthInputsView] updateAuthSessionWithCompletedStages failed");
        callback (nil, [NSError errorWithDomain:MXKAuthErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:[NSBundle mxk_localizedStringForKey:@"not_supported_yet"]}]);
    }
}

- (BOOL)setExternalRegistrationParameters:(NSDictionary *)registrationParameters
{
    // Presently we only support a registration based on next_link associated to a successful email validation.
    NSString *homeserverURL;
    NSString *identityURL;
    
    // Check the current authentication type
    if (self.authType != MXKAuthenticationTypeRegister)
    {
        NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong auth type");
        return NO;
    }
    
    // Retrieve the REST client from delegate
    MXRestClient *restClient;
    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
    {
        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
    }
    
    if (restClient)
    {
        // Sanity check on homeserver
        id hs_url = registrationParameters[@"hs_url"];
        if (hs_url && [hs_url isKindOfClass:NSString.class])
        {
            homeserverURL = hs_url;
            
            if ([homeserverURL isEqualToString:restClient.homeserver] == NO)
            {
                NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong homeserver URL");
                return NO;
            }
        }
        
        // Sanity check on identity server
        id is_url = registrationParameters[@"is_url"];
        if (is_url && [is_url isKindOfClass:NSString.class])
        {
            identityURL = is_url;
            
            if ([identityURL isEqualToString:restClient.identityServer] == NO)
            {
                NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong identity server URL");
                return NO;
            }
        }
    }
    else
    {
        NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: not supported");
        return NO;
    }
    
    // Retrieve other parameters
    NSString *clientSecret;
    NSString *sid;
    NSString *sessionId;
    
    id value = registrationParameters[@"client_secret"];
    if (value && [value isKindOfClass:NSString.class])
    {
        clientSecret = value;
    }
    value = registrationParameters[@"sid"];
    if (value && [value isKindOfClass:NSString.class])
    {
        sid = value;
    }
    value = registrationParameters[@"session_id"];
    if (value && [value isKindOfClass:NSString.class])
    {
        sessionId = value;
    }
    
    // Check validity of the required parameters
    if (!homeserverURL.length || !identityURL.length || !clientSecret.length || !sid.length || !sessionId.length)
    {
        NSLog(@"[AuthInputsView] setExternalRegistrationParameters failed: wrong parameters");
        return NO;
    }
    
    // Prepare the registration parameters (Ready to use)
    NSURL *identServerURL = [NSURL URLWithString:identityURL];
    externalRegistrationParameters = @{
                                       @"auth": @{@"session": sessionId, @"threepid_creds": @{@"client_secret": clientSecret, @"id_server": identServerURL.host, @"sid": sid}, @"type": kMXLoginFlowTypeEmailIdentity},
                                       };
    
    // Hide all inputs by default
    [self hideInputsContainer];
    
    return YES;
}

- (void)setSoftLogoutCredentials:(MXCredentials *)credentials
{
    softLogoutCredentials = credentials;
    self.userLoginTextField.text = softLogoutCredentials.userId;
    self.userLoginContainer.hidden = YES;
    self.phoneContainer.hidden = YES;

    [self displaySoftLogoutMessage];
}

- (void)displaySoftLogoutMessage
{
    // Take some shortcuts and make some assumptions (Riot uses MXFileStore and MXRealmCryptoStore) to
    // retrieve data to display as quick as possible
    MXRealmCryptoStore *cryptoStore = [[MXRealmCryptoStore alloc] initWithCredentials:self.softLogoutCredentials];
    BOOL keyBackupNeeded = [cryptoStore inboundGroupSessionsToBackup:1].count > 0;

    MXFileStore *fileStore = [[MXFileStore alloc] initWithCredentials:softLogoutCredentials];
    [fileStore asyncUsersWithUserIds:@[softLogoutCredentials.userId] success:^(NSArray<MXUser *> * _Nonnull users) {

        MXUser *myUser = users.firstObject;
        [fileStore close];

        [self displaySoftLogoutMessageWithUserDisplayname:myUser.displayname andKeyBackupNeeded:keyBackupNeeded];

    } failure:^(NSError * _Nonnull error) {
        NSLog(@"[AuthInputsView] displaySoftLogoutMessage: Cannot load displayname. Error: %@", error);
        [self displaySoftLogoutMessageWithUserDisplayname:nil andKeyBackupNeeded:keyBackupNeeded];
    }];
}

- (void)displaySoftLogoutMessageWithUserDisplayname:(NSString*)userDisplayname andKeyBackupNeeded:(BOOL)keyBackupNeeded
{
    // Use messageLabel for this message
    self.messageLabelTopConstraint.constant = 8;
    self.messageLabel.textColor = ThemeService.shared.theme.textPrimaryColor;
    self.messageLabel.hidden = YES;

    NSMutableAttributedString *message = [[NSMutableAttributedString alloc] initWithString:NSLocalizedStringFromTable(@"auth_softlogout_sign_in", @"Vector", nil)
                                                                    attributes:@{
                                                                                 NSFontAttributeName: [UIFont boldSystemFontOfSize:14]
                                                                                 }];

    [message appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];

    NSString *string = [NSString stringWithFormat:NSLocalizedStringFromTable(@"auth_softlogout_reason", @"Vector", nil),
                        softLogoutCredentials.homeServerName, userDisplayname, softLogoutCredentials.userId];
    [message appendAttributedString:[[NSAttributedString alloc] initWithString:string
                                                                    attributes:@{
                                                                                 NSFontAttributeName: [UIFont systemFontOfSize:14]
                                                                                 }]];

    if (keyBackupNeeded)
    {
        [message appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n\n"]];
        string = NSLocalizedStringFromTable(@"auth_softlogout_recover_encryption_keys", @"Vector", nil);
        [message appendAttributedString:[[NSAttributedString alloc] initWithString:string
                                                                        attributes:@{
                                                                                     NSFontAttributeName: [UIFont systemFontOfSize:14]
                                                                                     }]];
    }

    self.messageLabel.attributedText = message;
}

- (BOOL)areAllRequiredFieldsSet
{
    // Keep enable the submit button.
    return YES;
}

- (void)dismissKeyboard
{
    [self.userLoginTextField resignFirstResponder];
    [self.passWordTextField resignFirstResponder];
    [self.emailTextField resignFirstResponder];
    [self.phoneTextField resignFirstResponder];
    [self.repeatPasswordTextField resignFirstResponder];
    
    [super dismissKeyboard];
}

- (void)dismissCountryPicker
{
    [phoneNumberCountryPicker withdrawViewControllerAnimated:YES completion:nil];
    [phoneNumberCountryPicker destroy];
    phoneNumberCountryPicker = nil;
    
    [phoneNumberPickerNavigationController dismissViewControllerAnimated:YES completion:nil];
    phoneNumberPickerNavigationController = nil;
}

- (NSString*)userId
{
    return self.userLoginTextField.text;
}

- (NSString*)password
{
    return self.passWordTextField.text;
}

- (void)setCurrentLastContainer:(UIView*)currentLastContainer
{
    _currentLastContainer = currentLastContainer;
    
    CGRect frame = _currentLastContainer.frame;
    self.viewHeightConstraint.constant = frame.origin.y + frame.size.height;
}

#pragma mark -

- (BOOL)areThirdPartyIdentifiersSupported
{
    return ([self isFlowSupported:kMXLoginFlowTypeEmailIdentity] || [self isFlowSupported:kMXLoginFlowTypeMSISDN]);
}

- (BOOL)isThirdPartyIdentifierRequired
{
    // Check first whether some 3pids are supported
    if (!self.areThirdPartyIdentifiersSupported)
    {
        return NO;
    }
    
    // Check whether an account may be created without third-party identifiers.
    for (MXLoginFlow *loginFlow in currentSession.flows)
    {
        if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeEmailIdentity] == NSNotFound
             && [loginFlow.stages indexOfObject:kMXLoginFlowTypeMSISDN] == NSNotFound)
        {
            // There is a flow with no 3pids
            return NO;
        }
    }
    
    return YES;
}

- (BOOL)areAllThirdPartyIdentifiersRequired
{
    // Check first whether some 3pids are required
    if (!self.isThirdPartyIdentifierRequired)
    {
        return NO;
    }
    
    BOOL isEmailIdentityFlowSupported = [self isFlowSupported:kMXLoginFlowTypeEmailIdentity];
    BOOL isMSISDNFlowSupported = [self isFlowSupported:kMXLoginFlowTypeMSISDN];
    
    for (MXLoginFlow *loginFlow in currentSession.flows)
    {
        if (isEmailIdentityFlowSupported)
        {
            if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeEmailIdentity] == NSNotFound)
            {
                return NO;
            }
            else if (isMSISDNFlowSupported)
            {
                if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeMSISDN] == NSNotFound)
                {
                    return NO;
                }
            }
        }
        else if (isMSISDNFlowSupported)
        {
            if ([loginFlow.stages indexOfObject:kMXLoginFlowTypeMSISDN] == NSNotFound)
            {
                return NO;
            }
        }
    }
    
    return YES;
}

- (void)setThirdPartyIdentifiersHidden:(BOOL)thirdPartyIdentifiersHidden
{
    [self hideInputsContainer];
    
    UIView *lastViewContainer;
    
    if (thirdPartyIdentifiersHidden)
    {
        self.passWordTextField.returnKeyType = UIReturnKeyNext;

        self.userLoginTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                         initWithString:NSLocalizedStringFromTable(@"auth_user_name_placeholder", @"Vector", nil)
                                                         attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
        
        self.userLoginContainer.hidden = NO;
        self.passwordContainer.hidden = NO;
        self.repeatPasswordContainer.hidden = NO;
        
        self.passwordContainerTopConstraint.constant = 50;
        
        lastViewContainer = self.repeatPasswordContainer;
    }
    else
    {
        if ([self isFlowSupported:kMXLoginFlowTypeEmailIdentity])
        {
            if (self.isThirdPartyIdentifierRequired)
            {
                self.emailTextField.placeholder = NSLocalizedStringFromTable(@"auth_email_placeholder", @"Vector", nil);
            }
            else
            {
                self.emailTextField.placeholder = NSLocalizedStringFromTable(@"auth_optional_email_placeholder", @"Vector", nil);
            }
            
            self.emailTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                             initWithString:self.emailTextField.placeholder
                                                             attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
            
            self.emailContainer.hidden = NO;
            
            self.messageLabel.hidden = YES;
            self.messageLabel.text = NSLocalizedStringFromTable(@"auth_add_email_message", @"Vector", nil);
            
            lastViewContainer = self.emailContainer;
        }
        
        if ([self isFlowSupported:kMXLoginFlowTypeMSISDN])
        {
            self.phoneTextField.returnKeyType = UIReturnKeyDone;
            
            if (self.isThirdPartyIdentifierRequired)
            {
                self.phoneTextField.placeholder = NSLocalizedStringFromTable(@"auth_phone_placeholder", @"Vector", nil);
            }
            else
            {
                self.phoneTextField.placeholder = NSLocalizedStringFromTable(@"auth_optional_phone_placeholder", @"Vector", nil);
            }
            
            self.phoneTextField.attributedPlaceholder = [[NSAttributedString alloc]
                                                         initWithString:self.phoneTextField.placeholder
                                                         attributes:@{NSForegroundColorAttributeName: ThemeService.shared.theme.placeholderTextColor}];
            
            self.phoneContainer.hidden = YES;
            
            if (!_emailContainer.isHidden)
            {
                self.emailTextField.returnKeyType = UIReturnKeyNext;
                
                self.phoneContainerTopConstraint.constant = 50;
                
                if (self.areAllThirdPartyIdentifiersRequired)
                {
                    self.messageLabel.text = NSLocalizedStringFromTable(@"auth_add_email_and_phone_message", @"Vector", nil);
                }
                else
                {
                    self.messageLabel.text = NSLocalizedStringFromTable(@"auth_add_email_phone_message", @"Vector", nil);
                }
            }
            else
            {
                self.phoneContainerTopConstraint.constant = 0;
                
                self.messageLabel.hidden = YES;
                self.messageLabel.text = NSLocalizedStringFromTable(@"auth_add_phone_message", @"Vector", nil);
            }
            
            lastViewContainer = self.phoneContainer;
        }
        
        if (!self.messageLabel.isHidden)
        {
            [self.messageLabel sizeToFit];
            
            CGRect frame = self.messageLabel.frame;
            
            CGFloat offset = frame.origin.y + frame.size.height;
            
            self.emailContainerTopConstraint.constant = offset;
            self.phoneContainerTopConstraint.constant += offset;
        }
    }
    
    self.currentLastContainer = lastViewContainer;
    
    _thirdPartyIdentifiersHidden = thirdPartyIdentifiersHidden;
}

- (IBAction)selectPhoneNumberCountry:(id)sender
{
    if ([self.delegate respondsToSelector:@selector(authInputsView:presentViewController:animated:)])
    {
        phoneNumberCountryPicker = [CountryPickerViewController countryPickerViewController];
        phoneNumberCountryPicker.delegate = self;
        phoneNumberCountryPicker.showCountryCallingCode = YES;
        
        phoneNumberPickerNavigationController = [[RiotNavigationController alloc] init];
        
        // Set Riot navigation bar colors
        [ThemeService.shared.theme applyStyleOnNavigationBar:phoneNumberPickerNavigationController.navigationBar];
        
        [phoneNumberPickerNavigationController pushViewController:phoneNumberCountryPicker animated:NO];
        
        UIBarButtonItem *leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back_icon"] style:UIBarButtonItemStylePlain target:self action:@selector(dismissCountryPicker)];
        phoneNumberCountryPicker.navigationItem.leftBarButtonItem = leftBarButtonItem;
        
        [self.delegate authInputsView:self presentViewController:phoneNumberPickerNavigationController animated:YES];
    }
}

- (void)setIsoCountryCode:(NSString *)isoCountryCode
{
    _isoCountryCode = isoCountryCode;
    
    NSNumber *callingCode = [[NBPhoneNumberUtil sharedInstance] getCountryCodeForRegion:isoCountryCode];
    
    self.callingCodeLabel.text = [NSString stringWithFormat:@"+%@", callingCode.stringValue];
    
    self.isoCountryCodeLabel.text = isoCountryCode;
    
    // Update displayed phone
    [self textFieldDidChange:self.phoneTextField];
}

- (void)resetThirdPartyIdentifiers
{
    [self dismissKeyboard];
    
    self.emailTextField.text = nil;
    self.phoneTextField.text = nil;

    nbPhoneNumber = nil;
}

#pragma mark - MXKCountryPickerViewControllerDelegate

- (void)countryPickerViewController:(MXKCountryPickerViewController *)countryPickerViewController didSelectCountry:(NSString *)isoCountryCode
{
    self.isoCountryCode = isoCountryCode;
            
    nbPhoneNumber = [[NBPhoneNumberUtil sharedInstance] parse:self.phoneTextField.text defaultRegion:isoCountryCode error:nil];
    [self formatNewPhoneNumber];
    
    [self dismissCountryPicker];
}

#pragma mark - UITextField delegate

- (void)textFieldDidEndEditing:(UITextField*)textField
{
    if (textField == self.userLoginTextField && type == MXKAuthenticationTypeLogin)
    {
        if ([MXTools isMatrixUserIdentifier:self.userLoginTextField.text])
        {
            if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsView:autoDiscoverServerWithDomain:)])
            {
                NSString *domain = [self.userLoginTextField.text componentsSeparatedByString:@":"][1];
                [self.delegate authInputsView:self autoDiscoverServerWithDomain:domain];
            }
        }
    }
}

- (BOOL)textFieldShouldReturn:(UITextField*)textField
{
    if (textField.returnKeyType == UIReturnKeyDone)
    {
        // "Done" key has been pressed
        [textField resignFirstResponder];
        
        // Launch authentication now
        [self.delegate authInputsViewDidPressDoneKey:self];
    }
    else
    {
        //"Next" key has been pressed
        if (textField == self.userLoginTextField || textField == self.phoneTextField)
        {
            [self.passWordTextField becomeFirstResponder];
        }
        else if (textField == self.passWordTextField)
        {
            [self.repeatPasswordTextField becomeFirstResponder];
        }
        else if (textField == self.emailTextField)
        {
            [self.phoneTextField becomeFirstResponder];
        }
    }
    
    return YES;
}

#pragma mark - TextField listener

- (IBAction)textFieldDidChange:(id)sender
{
    UITextField* textField = (UITextField*)sender;
    
    if (textField == self.phoneTextField)
    {
        nbPhoneNumber = [[NBPhoneNumberUtil sharedInstance] parse:self.phoneTextField.text defaultRegion:self.isoCountryCode error:nil];
        
        [self formatNewPhoneNumber];
    }
}

#pragma mark -

- (void)hideInputsContainer
{
    // Hide all inputs container
    self.userLoginContainer.hidden = YES;
    self.passwordContainer.hidden = YES;
    self.emailContainer.hidden = YES;
    self.phoneContainer.hidden = YES;
    self.repeatPasswordContainer.hidden = YES;
    
    // Hide other items
    self.messageLabelTopConstraint.constant = 8;
    self.messageLabel.hidden = YES;
    self.recaptchaContainer.hidden = YES;
    self.termsView.hidden = YES;
    self.ssoButtonContainer.hidden = YES;
    
    _currentLastContainer = nil;
}

- (void)formatNewPhoneNumber
{
    if (nbPhoneNumber)
    {
        NSString *formattedNumber = [[NBPhoneNumberUtil sharedInstance] format:nbPhoneNumber numberFormat:NBEPhoneNumberFormatINTERNATIONAL error:nil];
        NSString *prefix = self.callingCodeLabel.text;
        if ([formattedNumber hasPrefix:prefix])
        {
            // Format the display phone number
            self.phoneTextField.text = [formattedNumber substringFromIndex:prefix.length];
        }
    }
}

- (BOOL)displayRecaptchaForm:(void (^)(NSString *response))callback
{
    // Retrieve the site key
    NSString *siteKey;
    
    id recaptchaParams = currentSession.params[kMXLoginFlowTypeRecaptcha];
    if (recaptchaParams && [recaptchaParams isKindOfClass:NSDictionary.class])
    {
        NSDictionary *recaptchaParamsDict = (NSDictionary*)recaptchaParams;
        siteKey = recaptchaParamsDict[@"public_key"];
    }
    
    // Retrieve the REST client from delegate
    MXRestClient *restClient;
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
    {
        restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
    }
    
    // Sanity check
    if (siteKey.length && restClient && callback)
    {
        [self hideInputsContainer];
        
        self.messageLabel.hidden = YES;
        self.messageLabel.text = NSLocalizedStringFromTable(@"auth_recaptcha_message", @"Vector", nil);
        
        self.recaptchaContainer.hidden = NO;
        self.currentLastContainer = self.recaptchaContainer;

        // IB does not support WKWebview in a xib before iOS 11
        // So, add it by coding

        // Do some cleaning/reset before
        for (UIView *view in self.recaptchaContainer.subviews)
        {
            [view removeFromSuperview];
        }

        MXKAuthenticationRecaptchaWebView *reCaptchaWebView = [MXKAuthenticationRecaptchaWebView new];
        reCaptchaWebView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.recaptchaContainer addSubview:reCaptchaWebView];

        // Disable the webview scrollView to avoid 2 scrollviews on the same screen
        reCaptchaWebView.scrollView.scrollEnabled = NO;

        [self.recaptchaContainer addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"|-[view]-|"
                                                 options:0
                                                 metrics:0
                                                   views:@{
                                                           @"view": reCaptchaWebView
                                                           }
          ]
         ];
        [self.recaptchaContainer addConstraints:
         [NSLayoutConstraint constraintsWithVisualFormat:@"V:|-[view]-|"
                                                 options:0
                                                 metrics:0
                                                   views:@{
                                                           @"view": reCaptchaWebView
                                                           }
          ]
         ];


        [reCaptchaWebView openRecaptchaWidgetWithSiteKey:siteKey fromHomeServer:restClient.homeserver callback:callback];
        
        return YES;
    }
    
    return NO;
}

// Tell whether a flow type is supported or not by this view.
- (BOOL)isSupportedFlowType:(MXLoginFlowType)flowType
{
    if ([flowType isEqualToString:kMXLoginFlowTypePassword])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeEmailIdentity])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeRecaptcha])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeMSISDN])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeDummy])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeTerms])
    {
        return YES;
    }
    else if ([flowType isEqualToString:kMXLoginFlowTypeCAS] || [flowType isEqualToString:kMXLoginFlowTypeSSO])
    {
        return YES;
    }

    return NO;
}

- (MXAuthenticationSession*)validateAuthenticationSession:(MXAuthenticationSession*)authSession
{
    // Check whether the listed flows in this authentication session are supported
    NSMutableArray *supportedFlows = [NSMutableArray array];
    
    for (MXLoginFlow* flow in authSession.flows)
    {
        // Check whether flow type is defined
        if (flow.type)
        {
            if ([self isSupportedFlowType:flow.type])
            {
                // Check here all stages
                BOOL isSupported = YES;
                if (flow.stages.count)
                {
                    for (NSString *stage in flow.stages)
                    {
                        if ([self isSupportedFlowType:stage] == NO)
                        {
                            NSLog(@"[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? @"login" : @"register"), stage);
                            isSupported = NO;
                            break;
                        }
                    }
                }
                else
                {
                    flow.stages = @[flow.type];
                }
                
                if (isSupported)
                {
                    [supportedFlows addObject:flow];
                }
            }
            else
            {
                NSLog(@"[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? @"login" : @"register"), flow.type);
            }
        }
        else
        {
            // Check here all stages
            BOOL isSupported = YES;
            if (flow.stages.count)
            {
                for (NSString *stage in flow.stages)
                {
                    if ([self isSupportedFlowType:stage] == NO)
                    {
                        NSLog(@"[AuthInputsView] %@: %@ stage is not supported.", (type == MXKAuthenticationTypeLogin ? @"login" : @"register"), stage);
                        isSupported = NO;
                        break;
                    }
                }
            }
            
            if (isSupported)
            {
                [supportedFlows addObject:flow];
            }
        }
    }
    
    if (supportedFlows.count)
    {
        if (supportedFlows.count == authSession.flows.count)
        {
            // Return the original session.
            return authSession;
        }
        else
        {
            // Keep only the supported flow.
            MXAuthenticationSession *updatedAuthSession = [[MXAuthenticationSession alloc] init];
            updatedAuthSession.session = authSession.session;
            updatedAuthSession.params = authSession.params;
            updatedAuthSession.flows = supportedFlows;
            return updatedAuthSession;
        }
    }
    
    return nil;
}

- (void)showValidationMSISDNDialogToPrepareParameters:(void (^)(NSDictionary *parameters, NSError *error))callback
{
    __weak typeof(self) weakSelf = self;
    
    if (inputsAlert)
    {
        [inputsAlert dismissViewControllerAnimated:NO completion:nil];
    }
    
    if (inputsAlert)
    {
        [inputsAlert dismissViewControllerAnimated:NO completion:nil];
    }
    
    inputsAlert = [UIAlertController alertControllerWithTitle:NSLocalizedStringFromTable(@"auth_msisdn_validation_title", @"Vector", nil) message:NSLocalizedStringFromTable(@"auth_msisdn_validation_message", @"Vector", nil) preferredStyle:UIAlertControllerStyleAlert];
    
    [inputsAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"abort"]
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * action) {
                                                      
                                                      if (weakSelf)
                                                      {
                                                          typeof(self) self = weakSelf;
                                                          self->inputsAlert = nil;
                                                          
                                                          if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewDidCancelOperation:)])
                                                          {
                                                              [self.delegate authInputsViewDidCancelOperation:self];
                                                          }
                                                      }
                                                      
                                                  }]];
    
    [inputsAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        textField.secureTextEntry = NO;
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDecimalPad;
        
    }];
    
    [inputsAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"submit"]
                                                    style:UIAlertActionStyleDefault
                                                  handler:^(UIAlertAction * action) {
                                                      
                                                      if (weakSelf)
                                                      {
                                                          typeof(self) self = weakSelf;
                                                          UITextField *textField = [inputsAlert textFields].firstObject;
                                                          NSString *smsCode = textField.text;
                                                          self->inputsAlert = nil;
                                                          
                                                          if (smsCode.length)
                                                          {
                                                              [self->submittedMSISDN submitValidationToken:smsCode success:^{
                                                                  
                                                                  // Retrieve the REST client from delegate
                                                                  MXRestClient *restClient;
                                                                  
                                                                  if (self.delegate && [self.delegate respondsToSelector:@selector(authInputsViewThirdPartyIdValidationRestClient:)])
                                                                  {
                                                                      restClient = [self.delegate authInputsViewThirdPartyIdValidationRestClient:self];
                                                                  }
                                                                  
                                                                  NSURL *identServerURL = [NSURL URLWithString:restClient.identityServer];
                                                                  NSDictionary *parameters;
                                                                  parameters = @{
                                                                                 @"auth": @{@"session":self->currentSession.session, @"threepid_creds": @{@"client_secret": self->submittedMSISDN.clientSecret, @"id_server": identServerURL.host, @"sid": self->submittedMSISDN.sid}, @"type": kMXLoginFlowTypeMSISDN},
                                                                                 @"username": self.userLoginTextField.text,
                                                                                 @"password": self.passWordTextField.text,
                                                                                 @"bind_msisdn": @(YES),
                                                                                 @"bind_email": @([self isFlowCompleted:kMXLoginFlowTypeEmailIdentity])
                                                                                 };
                                                                  
                                                                  callback(parameters, nil);
                                                                  
                                                              } failure:^(NSError *error) {
                                                                  
                                                                  NSLog(@"[AuthInputsView] Failed to submit the sms token");
                                                                  
                                                                  // Ignore connection cancellation error
                                                                  if (([error.domain isEqualToString:NSURLErrorDomain] && error.code == NSURLErrorCancelled))
                                                                  {
                                                                      return;
                                                                  }
                                                                  
                                                                  // Alert user
                                                                  NSString *title = [error.userInfo valueForKey:NSLocalizedFailureReasonErrorKey];
                                                                  NSString *msg = [error.userInfo valueForKey:NSLocalizedDescriptionKey];
                                                                  if (!title)
                                                                  {
                                                                      if (msg)
                                                                      {
                                                                          title = msg;
                                                                          msg = nil;
                                                                      }
                                                                      else
                                                                      {
                                                                          title = [NSBundle mxk_localizedStringForKey:@"error"];
                                                                      }
                                                                  }
                                                                  
                                                                  self->inputsAlert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
                                                                  
                                                                  [inputsAlert addAction:[UIAlertAction actionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"]
                                                                                                                  style:UIAlertActionStyleDefault
                                                                                                                handler:^(UIAlertAction * action) {
                                                                                                                    
                                                                                                                    if (weakSelf)
                                                                                                                    {
                                                                                                                        typeof(self) self = weakSelf;
                                                                                                                        self->inputsAlert = nil;
                                                                                                                        
                                                                                                                        // Ask again for the token
                                                                                                                        [self showValidationMSISDNDialogToPrepareParameters:callback];
                                                                                                                    }
                                                                                                                    
                                                                                                                }]];
                                                                  
                                                                  [self->inputsAlert mxk_setAccessibilityIdentifier:@"AuthInputsViewErrorAlert"];
                                                                  [self.delegate authInputsView:self presentAlertController:self->inputsAlert];
                                                                  
                                                              }];
                                                          }
                                                          else
                                                          {
                                                              // Ask again for the token
                                                              [self showValidationMSISDNDialogToPrepareParameters:callback];
                                                          }
                                                      }
                                                      
                                                  }]];
    
    [inputsAlert mxk_setAccessibilityIdentifier:@"AuthInputsViewMsisdnValidationAlert"];
    [self.delegate authInputsView:self presentAlertController:inputsAlert];
}

- (BOOL)displayTermsView:(dispatch_block_t)onAcceptedCallback
{
    // Extract data
    NSDictionary *loginTermsData = currentSession.params[kMXLoginFlowTypeTerms];
    MXLoginTerms *loginTerms;
    MXJSONModelSetMXJSONModel(loginTerms, MXLoginTerms.class, loginTermsData);

    if (loginTerms)
    {
        [self hideInputsContainer];

        self.messageLabel.hidden = YES;
        self.messageLabel.text = NSLocalizedStringFromTable(@"auth_accept_policies", @"Vector", nil);

        self.termsView.hidden = YES;
        self.currentLastContainer = self.termsView;

        self.termsView.delegate = self.delegate;
        [self.termsView displayTermsWithTerms:loginTerms onAccepted:onAcceptedCallback];

        return YES;
    }

    return NO;
}

#pragma mark - Flow state

/**
 Check if a flow (kMXLoginFlowType*) is part of the required flows steps.

 @param flow the flow type to check.
 @return YES if the the flow must be implemented.
 */
- (BOOL)isFlowSupported:(NSString *)flow
{
    for (MXLoginFlow *loginFlow in currentSession.flows)
    {
        if ([loginFlow.type isEqualToString:flow] || [loginFlow.stages indexOfObject:flow] != NSNotFound)
        {
            return YES;
        }
    }

    return NO;
}

/**
 Check if a flow (kMXLoginFlowType*) has already been completed.

 @param flow the flow type to check.
 @return YES if the the flow has been completedd.
 */
- (BOOL)isFlowCompleted:(NSString *)flow
{
    if (currentSession.completed && [currentSession.completed indexOfObject:flow] != NSNotFound)
    {
        return YES;
    }

    return NO;
}

@end
