# Automacao "comente a palavra-chave -> recebe DM" (comment-to-DM) por post do Instagram.
# Reusa a ingestao de comentario (CommentBuilder) e o envio comment-to-DM ja existentes.
class CreateInstagramCommentAutomations < ActiveRecord::Migration[7.1]
  def change
    create_table :instagram_comment_automations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :inbox, null: false, foreign_key: true
      t.string :name, null: false
      t.string :media_id                                  # nil = qualquer post do canal
      t.string :keywords                                  # csv de palavras-chave; vazio = qualquer comentario
      t.string :match_type, null: false, default: 'contains' # contains | exact | any
      t.text :dm_message, null: false
      t.string :dm_link                                   # opcional: link do botao/da DM
      t.string :dm_button_label                           # opcional: rotulo do botao (usa template)
      t.text :public_reply                                # opcional: resposta publica no comentario
      t.boolean :enabled, null: false, default: true
      t.boolean :once_per_user, null: false, default: true
      t.datetime :starts_at                               # janela de agendamento (opcional)
      t.datetime :ends_at
      t.integer :sent_count, null: false, default: 0
      t.jsonb :handled_commenter_ids, null: false, default: [] # idempotencia por usuario
      t.timestamps
    end
  end
end
