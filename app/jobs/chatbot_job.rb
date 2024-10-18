class ChatbotJob < ApplicationJob
  queue_as :default

  def perform(question)
    @question = question
    chatgpt_response = client.chat(
      parameters: {
        model: "gpt-4o-mini",
        messages: ai_converstion_log(question)
      }
    )

    new_content = chatgpt_response["choices"][0]["message"]["content"]
    @question.update(ai_answer: new_content)

    Turbo::StreamsChannel.broadcast_update_to(
      "question_#{@question.id}",
      target: "question_#{@question.id}",
      partial: "questions/question", locals: { question: @question })

  end

  private

  def client
    @client ||= OpenAI::Client.new
  end

  def ai_converstion_log(question)
    # [
    #  { role: "user", content: "Hi, how are you?"},
    #  { role: "assistant", content: "I'm good"}
    #  { role: "user", content: "Great"},
    #  { role: "assistant", content: "Thanks"
    #  ]

    # results << { role: "system", content: "You are a helpful assistant for an e-commerce website." }

    # questions.each do |question|
    #   results << { role: "user", content: question.user_question }
    #   results << { role: "assistant", content: question.ai_answer || "" }
    # end
    # return results


    results = []
    questions = question.user.questions
    system_text = "You are an assistant for an e-commerce website. 1. Always say the name of the product. 2. If you don't know the answer, you can say 'I don't know. If you don't have any products at the end of this message, say we don't have that.  Here are the products you should use to answer the user's questions: "

    nearest_products.each do |product|
      system_text += "** PRODUCT #{product.id}: name: #{product.name}, description: #{product.description}, price: #{product.price} **"
    end
    results << { role: "system", content: system_text }

    questions.each do |question|
      results << { role: "user", content: question.user_question }
      results << { role: "assistant", content: question.ai_answer || "" }
    end

    return results


  end

  def nearest_products
    response = client.embeddings(
      parameters: {
        model: 'text-embedding-3-small',
        input: @question.user_question
      }
    )
    question_embedding = response['data'][0]['embedding']
    return Product.nearest_neighbors(
      :embedding, question_embedding,
      distance: "euclidean"
    ) # you may want to add .first(3) here to limit the number of results
  end

end
