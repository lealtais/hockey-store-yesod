# Projeto Final – Aplicação Web com Yesod (Haskell)

> ⚠️ Rascunho inicial. Os itens marcados com `TODO` serão preenchidos conforme o projeto avançar.

## 1. Descrição do projeto
- **Nome:** Hockey Store (loja de equipamentos de hockey)
- **Objetivo:** loja virtual de equipamentos de hockey (patins, tacos, proteções, uniformes) com cadastro de produtos, clientes e pedidos
- **Principais funcionalidades:** `TODO`
- **Arquitetura escolhida:** A (monolítica com Yesod + Hamlet)

## 2. Tecnologias utilizadas
- Haskell + [Yesod](https://www.yesodweb.com/)
- Persistent (ORM) + SQLite
- Shakespearean Templates (Hamlet, Cassius, Lucius) – se Opção A
- Stack (build) e Git/GitHub

## 3. Instruções de execução
```bash
git clone https://github.com/lealtais/hockey-store-yesod.git
cd hockey-store-yesod
stack build
stack exec hockey-store
```

Depois acesse http://localhost:3000. Requer o [Haskell Stack](https://docs.haskellstack.org/) instalado; o primeiro build baixa o GHC e as dependências e demora.

## 4. Estrutura do banco de dados (mínimo 7 tabelas reais)
| # | Tabela | Campos principais | Relacionamentos / restrições |
|---|--------|-------------------|------------------------------|
| 1 | `Categoria` | `nome` | `nome` único |
| 2 | `Marca` | `nome`, `pais` (opcional) | `nome` único |
| 3 | `Produto` | `nome`, `descricao` (opcional), `preco`, `estoque`, `categoriaId`, `marcaId` | FK → `Categoria`, `Marca` |
| 4 | `Cliente` | `nome`, `email`, `telefone` (opcional) | `email` único |
| 5 | `Endereco` | `clienteId`, `cep`, `logradouro`, `numero`, `complemento` (opcional), `bairro`, `cidade`, `uf` | FK → `Cliente` |
| 6 | `Pedido` | `clienteId`, `enderecoId` (opcional), `status`, `total`, `criadoEm` | FK → `Cliente`, `Endereco` |
| 7 | `ItemPedido` | `pedidoId`, `produtoId`, `quantidade`, `precoUnitario` | FK → `Pedido`, `Produto` |

## 5. Integração com API externa
- **API:** ViaCEP (https://viacep.com.br)
- **Finalidade:** preencher automaticamente o endereço de entrega do cliente a partir do CEP

## 6. Integrantes
| Nome | Conta GitHub | Principais contribuições |
|------|--------------|--------------------------|
| `TODO` | | |

## 7. (Somente se REST) Endpoints
| Método | Rota | Finalidade |
|--------|------|-----------|
| GET | `TODO` | |

## Hospedagem (opcional)
`TODO`

