{
  title: 'Qualtrics',

  connection: {
    fields: [
      { name: 'host', control_type: 'subdomain', url: '.qualtrics.com', optional: false },
      { name: 'username', label: 'username/email', optional: false },
      { name: 'api_key', control_type: 'password', optional: false }
    ],

    authorization: {
      type: 'api_key',

      credentials: ->(connection) {
        headers("X-API-TOKEN": connection['api_key'])
      }
    }
  },

  test: ->(connection) {
    get("https://#{connection['host']}.qualtrics.com/API/v3/users")
  },

  object_definitions: {
    survey: {
      fields: ->(connection, config_input) {
        url = "https://#{connection['host']}.qualtrics.com/API/v3/surveys/#{connection['survey_id']}"
        questions = get(url)['result']['questions']
        schema = questions.map do |k,v|
                   { name: v["questionText"] }
                 end
      }
    },

    survey_questions_picklist: {
      fields: ->(connection, config_input){
        results = []
          get("https://#{connection['host']}.qualtrics.com/API/v3/surveys/#{config_input['answer_surveyID']}")['result']['exportColumnMap']
          .map do |question, value|
            results << { name: (question.split("_").first) }
          end

        results
      }
    },
    subscription_response: {
       fields: ->(connection) {
         [
                 { name: 'Topic'},
                 { name: 'Status'},
                 { name: 'SurveyID'},
                 { name: 'ResponseID'},
                 { name: 'BrandID'}
         ]
       }
    },

    Users: {
       fields: ->(connection){
         [
           { name: 'id'},
           { name: 'divisionId'},
           { name: 'username'},
           { name: 'firstName'},
           { name: 'lastName'},
             { name: 'UserType'},
           { name: 'email'},
           { name: 'accountStatus'}
         ]
       }
    },

    Groups: {
       fields: ->(connection){
         [
           { name: 'id'},
           { name: 'type'},
           { name: 'autoMembership'},
           { name: 'creationDate', type: :datetime},
           { name: 'creatorId'}
         ]
       }
    },

    mailing_list: {
      fields: ->(connection) {
       [
         { name: "libraryId"},
         { name: "id"},
         { name: "name"},
         { name: "category"}
       ]
      }
    },

    response_detail: {
      fields: ->(connection){
				[
        			{ name: 'Id'},
          		{ name: 'ResponseSet'},
              { name: 'Name'},
              { name: 'ExternalDataReference'},
              { name: 'EmailAddress'},
              { name: 'IPAddress'},
              { name: 'Status'},
              { name: 'StartDate', type: :datetime},
              { name: 'EndDate', type: :datetime},
              { name: 'Finished'},
              { name: 'Score', type: :object, properties: [
                   { name: 'Sum', type: :integer}, { name: 'WeightedMean', type: :decimal}, { name: 'WeightedStdDev', type: :decimal}
                ]
              },
              { name: 'Questions', type: :array, of: :object, properties: [
                  { name: 'name'},
                	{ name: 'score', type: :integer}
                ]
              }
          ]
      }
    },

    downloaded_response: {
       fields: ->(connection){
          [
             { name: 'result', type: :object, properties: [{ name: 'id'}]},
             { name: 'meta', type: :object, properties: [{ name: 'httpStatus'}]}
          ]
       }
    },

    permissions: {
          fields: ->(connection) {
             permissions = get("https://#{connection['host']}.qualtrics.com/API/v3/surveys/#{connection['permissions']}").
              map { |field| { name: field['id']} }
          }
       },

    config_survey_list: {
      fields: ->(connection, config_input){
        [
          { name: config_input['SurveyID']}
          ]
        }
      },
    contact: {
      fields: ->(connection) {
       [
         { name: 'id'},
         { name: 'firstName'},
         { name: 'lastName'},
         { name: 'email'},
         { name: 'externalDataReference'},
         { name: 'language'},
         { name: 'unsubscribed', type: :boolean},
         { name: 'responseHistory', type: :array, of: :object, properties: [
           { name: 'responseId'},
           { name: 'surveyId'},
           { name: 'date', type: :datetime},
           { name: 'emailDistributionId'},
           { name: 'finishedSurvey', type: :boolean}
           ]},
         { name: 'emailHistory', type: :array, of: :object, properties: [
           { name: 'emailDistributionId'},
           { name: 'date', type: :datetime},
           { name: 'type'},
           { name: 'result'},
           { name: 'surveyId'},
           { name: 'read', type: :boolean }
           ]}
       ]
      }
    }
  },

  actions: {
    add_contact_to_Mailing_list: {
      config_fields: [
        { name: 'panel_id', optional: false, hint: "Panels are also called Mailing Lists. Choose \"None\" if you wish to fill in your own Mailist List ID using the next field", control_type: 'select', pick_list: 'panels'},
        { name: 'panel_by_id', optional: true, hint: 'Insert your own Mailing List ID here if you chose "None" in the previous field'},
      ],

      input_fields:->(object_definitions){

        [
          { name: 'FirstName'},
          { name: 'LastName'},
          { name: 'Email'},
          { name: 'ExternalDataRef'},
          { name: 'Language'},
        ]
        },

      execute: ->(connection, input){
        library = get("https://#{connection['host']}.qualtrics.com/API/v3/mailinglists/#{(input['panel_id'].include?("None") ? input['panel_by_id'] : input['panel_id'])}")['result']['libraryId']

        auth_data = {
          	User: connection['username'],
            Token: connection['api_key'],
            Format: 'JSON',
            Version: '2.0',
            LibraryID: library,
            PanelID: (input['panel_id'].include?("None") ? input['panel_by_id'] : input['panel_id'])
          }

        result = get("https://survey.qualtrics.com/WRAPI/ControlPanel/api.php?Request=addRecipient").params(
            auth_data.merge(input))['Result']


        },

      output_fields:->(object_definitions){
        [{ name: 'RecipientID'}]

        }
      },
        #Allows you to extract the data from a given object
    Extract_answer_from_Object: {
      config_fields: [
        {
          name: 'answer_surveyID',
          optional: false,
          control_type: 'select',
          pick_list: 'surveys',
          hint: 'Insert the SurveyID that you\'d like to extract answers from. This is usually from a Survey Response trigger'
        }

      ],

      input_fields:->(object_definitions){
        questions_picklist = []
        object_definitions['survey_questions_picklist'].map { |field| questions_picklist << [field[:name],field[:name]] }
        questions_picklist = questions_picklist.sort.uniq

        [
          { name: 'Compact_answer', optional: false, hint: "Extract a comma-separated values of this hash for a specific question. This will return a string. When putting in your input, make sure that your formula mode is turned on"},
          { name: 'ChooseQuestion', control_type: 'select', pick_list: questions_picklist,
            hint: 'Specify which question would you like to get data for. This is populated based on the Survey ID given in the Connection', optional: false}
          ]

        },
        execute:->(connection, input){

          { answer: (input['Compact_answer'])[input['ChooseQuestion']].map {|field| field[:value]}.smart_join(",") }
        },
        output_fields:->(object_definitions){
          [{ name: 'answer'}]
        }
      },

    get_response_details_by_id: {
      input_fields:->(){
        [{ name: 'SurveyID', optional: false }, { name: 'ResponseID', optional: false, hint: "ResponseID is usually the output of a Survey Response Trigger"}]
      },

      execute: ->(connection, input){

        result = get(
          "https://survey.qualtrics.com/WRAPI/ControlPanel/api.php?API_SELECT=ControlPanel&Version=2.5&Request=getLegacyResponseData",
          User: connection['username'],
          Token: connection['api_key'],
          Format: 'JSON',
          SurveyID: input['SurveyID'],
          ResponseID: input['ResponseID']
        ).map do |id, response|
          questions = []
          response.each do |key, value|
            if key.starts_with?("Q")
              questions << { name: key, score: value }
            end
          end
          questions.each { |q| response.delete(q[:name]) }
          response['Questions'] = questions
          response['Id'] = id
          response
        end
        { result: result }
      },

      output_fields: ->(object_definitions){
        [
          { name: "result", type: :array, of: :object, properties: object_definitions['response_detail'] }
        ]
      }
    },

    get_mailing_lists: {
       input_fields: ->(){},

       execute: ->(connection, input){
         mailing_lists =  get("https://#{connection['host']}.qualtrics.com/API/v3/mailinglists")['result']['elements']

         { mailing_lists: mailing_lists }
       },
       output_fields: ->(object_definitions){
         [  { name: 'mailing_lists', type: :array, of: :object, properties: object_definitions['mailing_list'] } ]
       }
    },

    create_mailing_list: {
       input_fields: ->(){
         [
          {name: 'libraryId', optional: false, hint: 'The Library ID can be one of the following existing IDs: User ID, Group ID', control_type: 'select', pick_list: 'users_groups'},
          { name: 'name', optional: false},
          { name: 'category', hint: 'Category in which to create the new mailing list'}
         ]
       },

       execute: ->(connection, input){
         data = post("https://co1.qualtrics.com/API/v3/mailinglists").
           payload(name: input['name'],libraryId: input['libraryId'])
         data = data['result']
       },

       output_fields: ->(object_definitions){
         [{name: 'id'}]
       }
    },

    get_all_users: {
      input_fields: ->(){},
      execute: ->(connection, input){
        data = get("https://#{connection['host']}.qualtrics.com/API/v3/users")['result']['elements']

        { Users: data }
      },
      output_fields: ->(object_definitions){
        [ { name: 'Users', type: :array, of: :object, properties: object_definitions['Users'] } ]
      }
    },

    get_contacts_of_mailing_list: {
      input_fields: ->(){
          [ { name: 'mailing_list_id', optional: false }]
        },
      execute: ->(connection, input){
           contacts = get("https://#{connection['host']}.qualtrics.com/API/v3/mailinglists/#{input['mailing_list_id']}/contacts")['result']['elements']

           { contacts: contacts }
        },
      output_fields: ->(object_definitions){
         [{ name: 'contacts', type: :array, of: :object, properties: object_definitions['contact'] } ]
        }
    },

    get_all_groups: {
      input_fields: ->(){},
      execute: ->(connection, input){
        result = get("https://#{connection['host']}.qualtrics.com/API/v3/groups")
        result = result['result']['elements']

        { groups: result }
      },
      output_fields: ->(object_definitions){
        [ { name: 'groups', type: :array, of: :object, properties: [{ name: 'id'}, {name: 'name'}] } ]
      }
    },

    get_group_details: {
      input_fields: ->(){
        [{ name: 'groupID', optional: false, control_type: 'select', pick_list: 'groups'}]
        },
      execute: ->(connection, input){
        	result = get("https://#{connection['host']}.qualtrics.com/API/v3/groups/#{input['groupID']}")['result']
        },
      output_fields: ->(object_definitions){
        object_definitions['Groups']
        }
    },

    get_library_messages: {
      input_fields: ->(){
        [
          { name: "Library", label: 'LibraryID',  optional: false, hint: 'The Library ID can be one of the following IDs: User ID, Group ID', control_type: 'select', pick_list: 'users_groups'},
          { name: "category", optional: true, hint: 'Category filter', control_type: 'select',
            pick_list: 'categories'}
        ]
      },

      execute: ->(connection, input){
        result = get("https://#{connection['host']}.qualtrics.com/API/v3/libraries/#{input['Library']}/messages")['result']['elements']

        { result: result }
      },

      output_fields: ->(object_definitions){
        [
          { name: 'result', type: :array, of: :object, properties: [
              { name: 'id'},
              { name: 'description'},
              { name: 'category'}
            ]}
        ]
      }
    },

    Create_Survey_Distribution: {
      input_fields: ->() {
        [
          { name: 'sendDate', type: :datetime, optional: false },
          { name: 'header', type: :object, properties: [
             { name: 'fromEmail', type: :string, optional: false},
             { name: 'fromName', type: :string, optional: false},
             { name: 'replyToEmail', type: :string, optional: true},
             { name: 'subject', type: :string, optional: false},
          ]},
          { name: 'recipients', type: :object, hint: 'Either MailingListID or ContactID must be present', properties: [
            { name: 'mailingListId', type: :string, optional: true,
              	hint: 'Either MailingListID or ContactID must be present. A Mailinglist must be used when creating a survey distribution.
											 To find the right MailingListID, go to your Qualtrics UI to determine it'},
            { name: 'contactId', type: :string, optional: true},
          ]},
          { name: 'message', type: :object, properties: [
            { name: 'messageId', type: :string, optional: false,
              hint: 'a Message ID contains a default template of the message for your survey distribution'},
            { name: 'libraryId', control_type: 'select', pick_list: 'users_groups', optional: false,
              hint: 'can be either an UserID or a GroupID'},
          ]},
          { name: 'surveyLink', type: :object, properties: [
            { name: 'surveyId', type: :string, optional: false, control_type: 'select', pick_list: 'surveys'},
            { name: 'expirationDate', type: :string, optional: true},
            { name: 'type', control_type: 'select', pick_list:
              [
                	["Individual", "Individual"],
                	["Multiple", "Multiple"],
                	["Anonymous", "Anonymous"]
              ],
              optional: true,
              hint: " If Individual, one unique link for each recipient will be generated that can be taken one time.
											If Multiple, then a unique link is sent out to each recipient that can be taken multiple times.
											If Anonymous, then the same generic link is sent to all recipients and can be taken multiple times"}
          ]}
        ]
      },

      execute: ->(connection,input) {
        #form objects and delete input

         input['sendDate'] = input['sendDate'].to_time.iso8601

        post("https://#{connection['host']}.qualtrics.com/API/v3/distributions", input)['result']
      },

      output_fields: ->(object_definitions){
        [{ name: 'id'}]
      }
    },

  },

  triggers: {

    new_survey_response: {
      description: 'New survey response for Qualtrics',
      type: :paging_desc,

      input_fields: ->(object_definitions) {
        [
          { name: 'survey_id', optional: false }
          ]
        },

      webhook_subscribe: ->(webhook_url,connection,input,recipe_id) {
        post("https://#{connection['host']}.qualtrics.com/API/v3/eventsubscriptions").
          payload(publicationUrl: webhook_url,
                  topics: 'surveyengine.completedResponse.'+ input['survey_id'])
      },


      webhook_unsubscribe: ->(webhook, connection) {
         delete("https://co1.qualtrics.com/API/v3/eventsubscriptions" + webhook['id'])
#          delete("https://#{connection['host']}.qualtrics.com/API/v3/eventsubscriptions" + webhook['id'])
      },

      webhook_notification: ->(input, payload) {
        payload
      },

      dedup: ->(response){
        response['ResponseID']
      },

      output_fields: ->(object_definitions) {
        object_definitions['subscription_response']

      }
    }
  },

  pick_lists: {
    panels: ->(connection){
      panels = [["None","None"]]
      get("https://#{connection['host']}.qualtrics.com/API/v3/mailinglists")['result']['elements']
      	.map { |data| panels << [data['name'], data['id']]  }

      panels
    },

    mailing_lists: ->(connection) {
      get("https://#{connection['host']}.qualtrics.com/API/v3/mailinglists")['result']['elements']
      		.map { |data| [data['name'], data['id']]  }
    },

    surveys: ->(connection) {
      get("https://#{connection['host']}.qualtrics.com/API/v3/surveys")['result']['elements']
      		.map { |data| [data['name'], data['id']]}
    },

    users: ->(connection){
	    get("https://#{connection['host']}.qualtrics.com/API/v3/users")['result']['elements']
      		.map { |data| [data['username'], data['id']]}
    },

    groups: ->(connection){
      get("https://#{connection['host']}.qualtrics.com/API/v3/groups")['result']['elements']
      		.map { |data| [data['name'], data['id']]}
    },

    users_groups: ->(connection){
       users_groups = get("https://#{connection['host']}.qualtrics.com/API/v3/users")['result']['elements']
      		.map { |data| [data['username'] + " - UserID", data['id']]}.concat(
            get("https://#{connection['host']}.qualtrics.com/API/v3/groups")['result']['elements']
            .map { |data| [data['name'] + " - GroupID", data['id']]}
          )
    },

    categories: ->(connection){
      [
        ["invite","invite"],["inactiveSurvey","inactiveSurvey"],
        ["reminder","reminder"],["thankYou", "thankYou"],
        ["endOfSurvey","endOfSurvey"],["general","general"],
        ["lookAndFeel","lookAndFeel"],["emailSubject","emailSubject"],
        ["smsInvite","smsInvite"]
      ]
    }
  }
}
			
