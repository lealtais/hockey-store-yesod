# Hockey Store

## 1. Descrição do projeto

Aplicação web para gerenciar uma loja de equipamentos de hockey. O sistema oferece cadastro, consulta, edição e exclusão de categorias, marcas, produtos, clientes e endereços, além do fluxo de pedidos e itens. O cadastro de endereço pode preencher logradouro, bairro, cidade e UF a partir do CEP.

## 2. Tecnologias utilizadas

- Haskell e Yesod no backend
- Persistent como ORM e SQLite como banco de dados
- Hamlet para os templates HTML e Lucius para os estilos
- Stack para dependências, build e execução
- ViaCEP para consultar dados de endereço pelo CEP

## 3. Instruções de execução

Instale o [Haskell Stack](https://docs.haskellstack.org/) e execute:

```bash
git clone https://github.com/lealtais/hockey-store-yesod.git
cd hockey-store-yesod
stack build
stack exec hockey-store
```

A aplicação fica disponível em <http://localhost:3000>. O primeiro build pode baixar o GHC e as dependências.

O login normal usa OpenID. Para uma demonstração local com login fictício, crie um arquivo local `dev-auth.yml` com `auth-dummy-login: true` e execute `stack exec -- hockey-store dev-auth.yml`. Não versione esse arquivo de configuração.

## 4. Estrutura do banco de dados

O domínio da loja possui sete tabelas. A autenticação do Yesod também mantém as tabelas auxiliares `User` e `Email`.

| Tabela | Campos principais | Relacionamentos e restrições |
|---|---|---|
| `Categoria` | `nome` | Nome único |
| `Marca` | `nome`, `pais` opcional | Nome único |
| `Produto` | `nome`, `descricao`, `preco`, `estoque`, `categoriaId`, `marcaId` | FKs para `Categoria` e `Marca`; preço armazenado como `Int` em centavos |
| `Cliente` | `nome`, `email`, `telefone`, `userId` | E-mail único; FK opcional para `User` |
| `Endereco` | `clienteId`, `cep`, `logradouro`, `numero`, `complemento`, `bairro`, `cidade`, `uf` | FK para `Cliente` |
| `Pedido` | `clienteId`, `enderecoId`, `status`, `total`, `criadoEm` | FK para `Cliente` e FK opcional para `Endereco`; status `Aberto`, `Pago`, `Enviado` ou `Cancelado`; total em centavos |
| `ItemPedido` | `pedidoId`, `produtoId`, `quantidade`, `precoUnitario` | FKs para `Pedido` e `Produto`; combinação pedido/produto única; preço unitário em centavos |

As tabelas são criadas e atualizadas pelas migrações do Persistent na inicialização do aplicativo.

## 5. Integração com API externa

A aplicação consulta a API gratuita [ViaCEP](https://viacep.com.br), no endpoint `https://viacep.com.br/ws/{cep}/json/`. No formulário de endereço, a ação **Buscar CEP** consulta a API no servidor e preenche CEP, logradouro, bairro, cidade e UF antes de salvar o endereço do cliente. CEP inválido, inexistente e falhas na consulta são apresentados como mensagens para o usuário.

## 6. Integrantes

| Nome | Conta GitHub | Principais contribuições |
|---|---|---|
| Taís Leal Almeida | `@lealtais` | Setup Yesod + SQLite, modelagem das 7 tabelas (`StatusPedido`, centavos em `Int`, `UniqueItemPedido`, `Cliente.userId`), CRUDs de Categoria, Marca e Produto, autenticação e proteção CSRF |
| Ricardo Panighel | `@ricardopanighel` | Layout visual, navegação e Home (`Hamlet`/`Lucius`), CRUD de Cliente, fluxo de Pedido e ItemPedido com cálculo de total e baixa de estoque, mensagens padronizadas e página 404 |
| Lucas Silva Fagundes | `@LucasSdevi` | Integração com a API ViaCEP (`Api.ViaCEP`), CRUD de Endereço com preenchimento por CEP, seed de demonstração (`Seed`), testes (`ViaCEPSpec`, `SeedSpec`) e documentação final (`README.md`) |
